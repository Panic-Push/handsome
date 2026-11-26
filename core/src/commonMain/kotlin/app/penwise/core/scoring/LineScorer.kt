package app.penwise.core.scoring

import app.penwise.core.geometry.Geometry
import app.penwise.core.geometry.Vec
import app.penwise.core.model.InputKind
import app.penwise.core.model.Ink
import app.penwise.core.template.LetterTemplate
import kotlin.math.abs
import kotlin.math.ln
import kotlin.math.roundToInt
import kotlin.math.sqrt

/** One letter of a word or line, placed at [x] (line units) on the writing line. */
data class PlacedLetter(
    val template: LetterTemplate,
    val x: Double,
    /** Which word (0-based) this letter belongs to. */
    val word: Int,
)

data class LetterResult(val index: Int, val glyph: String, val score: Int, val missing: Boolean)

data class WordResult(val text: String, val score: Int, val letters: List<LetterResult>)

data class LineScore(
    val overall: Int,
    val shape: Int,
    val size: Int,
    val baseline: Int,
    /** Null when there is only one word, or when tracing a model. */
    val spacing: Int?,
    val smoothness: Int,
    val direction: Int?,
    val words: List<WordResult>,
    val issues: List<Issue>,
) {
    val tip: String? get() = issues.firstOrNull()?.message
}

/** Lays text out on a line the way the app draws its models. */
object LineLayout {
    /** Gap between letters, in line units: print letters stand apart, cursive ones touch. */
    fun letterGap(cursive: Boolean) = if (cursive) 0.0 else 0.14

    const val WORD_GAP = 0.45
    const val PUNCTUATION_WIDTH = 0.2

    /**
     * Places each character of [text] that has a template. Spaces start a new
     * word; other characters without a template (punctuation) just take a little room.
     */
    fun place(text: String, templates: Map<String, LetterTemplate>, cursive: Boolean): List<PlacedLetter> {
        val out = mutableListOf<PlacedLetter>()
        var x = 0.0
        var word = 0
        var wordHasLetters = false
        for (ch in text) {
            val glyph = ch.toString()
            if (ch == ' ') {
                if (wordHasLetters) { word += 1; wordHasLetters = false }
                x += WORD_GAP
                continue
            }
            val template = templates[glyph]
            if (template == null) {
                x += PUNCTUATION_WIDTH
                continue
            }
            out += PlacedLetter(template, x, word)
            wordHasLetters = true
            x += template.width + letterGap(cursive)
        }
        return out
    }
}

/**
 * Scores a word or a whole line of handwriting letter by letter.
 *
 * Each ink point is given to the nearest model letter, then every letter's
 * shape is compared with its template. Across the line it also judges size
 * consistency, the baseline, word spacing (free writing) and smoothness.
 */
class LineScorer {

    /** The learner traced a model drawn at the [letters]' positions. */
    fun scoreTraced(ink: Ink, letters: List<PlacedLetter>): LineScore =
        score(ink, letters, traced = true)

    /**
     * The learner wrote the text freely on the line. The ink is stretched
     * sideways onto the model (heights are kept, so size and baseline are judged as written).
     */
    fun scoreFree(ink: Ink, letters: List<PlacedLetter>): LineScore =
        score(ink, letters, traced = false)

    private fun score(ink: Ink, letters: List<PlacedLetter>, traced: Boolean): LineScore {
        val raw = ink.strokes.map { s -> s.points.map { Vec(it.x, it.y) } }.filter { it.isNotEmpty() }
        val finger = ink.input == InputKind.FINGER
        val tol = (if (traced) 0.12 else 0.2) * (if (finger) 1.5 else 1.0)
        if (letters.isEmpty()) return empty(letters, "There is nothing to write here.")
        if (raw.isEmpty()) return empty(letters, "Nothing was written yet.")

        val models = letters.map { l -> l.template.strokes.map { s -> Geometry.resample(s.toVecs(), 24).map { Vec(it.x + l.x, it.y) } } }
        val modelPoints = models.map { it.flatten() }
        val allModel = modelPoints.flatten()

        // Free writing: stretch the ink sideways so it spans the model.
        val aligned = if (traced) raw else stretchSideways(raw, allModel)

        // Give each ink point (densely resampled) to the nearest model letter.
        val dense = aligned.map { Geometry.resampleBySpacing(it, 0.02) }
        val rawDense = raw.map { Geometry.resampleBySpacing(it, 0.02) }
        val owned = List(letters.size) { mutableListOf<Vec>() }
        val ownedRaw = List(letters.size) { mutableListOf<Vec>() }
        for (s in dense.indices) {
            val pts = dense[s]
            val rawPts = rawDense[s]
            for (k in pts.indices) {
                val p = pts[k]
                var best = -1
                var bestD = Double.MAX_VALUE
                for (i in modelPoints.indices) {
                    for (q in modelPoints[i]) {
                        val d = p.distanceTo(q)
                        if (d < bestD) { bestD = d; best = i }
                    }
                }
                if (best >= 0 && bestD < 0.6) {
                    owned[best] += p
                    ownedRaw[best] += rawPts[minOf(k, rawPts.size - 1)]
                }
            }
        }

        val results = letters.indices.map { i ->
            val mine = owned[i]
            if (mine.size < 3) {
                LetterResult(i, letters[i].template.glyph, 0, missing = true)
            } else {
                val d = Geometry.shapeDistance(mine, modelPoints[i])
                val sc = LetterScorer.toScore(d, tol)
                LetterResult(i, letters[i].template.glyph, sc, missing = d > tol * 1.6)
            }
        }
        val shape = average(results.map { it.score.toDouble() })

        // Baseline: bottoms of letters that don't hang below the line.
        val sitting = letters.indices.filter { boundsOf(letters[it]).maxY <= 1.05 && ownedRaw[it].size >= 3 }
        val bottoms = sitting.map { Geometry.bounds(ownedRaw[it]).maxY }
        val baselineDev = if (bottoms.isEmpty()) 0.0 else bottoms.map { abs(it - 1.0) }.average()
        val baseline = LetterScorer.toScore(baselineDev, 0.2 * (if (finger) 1.5 else 1.0))

        // Size: heights of the small letters (between the dashed line and the baseline).
        val small = letters.indices.filter {
            val b = boundsOf(letters[it]); b.minY >= 0.45 && b.maxY <= 1.05 && ownedRaw[it].size >= 3
        }
        val heights = small.map { Geometry.bounds(ownedRaw[it]).height }
        val sizeSpread = spread(heights)
        val meanHeight = if (heights.isEmpty()) 0.5 else heights.average()
        val size = minOf(
            LetterScorer.toScore(sizeSpread, 0.35),
            LetterScorer.toScore(abs(ln(maxOf(meanHeight, 0.05) / 0.5)), 0.45),
        )

        // Word spacing (free writing only): gaps between neighbouring words as written.
        val wordCount = (letters.maxOfOrNull { it.word } ?: 0) + 1
        var spacing: Int? = null
        var gaps = emptyList<Double>()
        if (!traced && wordCount >= 3) {
            val spans = (0 until wordCount).mapNotNull { w ->
                val pts = letters.indices.filter { letters[it].word == w }.flatMap { ownedRaw[it] }
                if (pts.isEmpty()) null else Geometry.bounds(pts)
            }
            gaps = spans.zipWithNext { a, b -> b.minX - a.maxX }
            if (gaps.size >= 2) spacing = LetterScorer.toScore(spread(gaps.map { maxOf(it, 0.01) }), 0.6)
        }

        var jitterSum = 0.0
        var jitterLen = 0.0
        for (s in raw) {
            val len = Geometry.pathLength(s)
            if (len < LetterScorer.TINY_STROKE) continue
            jitterSum += Geometry.jitter(s) * len
            jitterLen += len
        }
        val smoothness = if (jitterLen == 0.0) 100 else LetterScorer.toScore(jitterSum / jitterLen, 0.012 * (if (finger) 1.5 else 1.0))

        val direction = if (traced) {
            val agreement = Geometry.directionAgreement(raw.map { Geometry.resampleBySpacing(it, 0.03) }, models.flatten())
            (Geometry.clamp01((agreement - 0.5) / 0.4) * 100).roundToInt()
        } else null

        val parts = listOfNotNull(
            shape to 0.5, baseline to 0.15, size to 0.15, spacing?.let { it to 0.1 }, smoothness to 0.1,
            direction?.let { it to 0.1 },
        )
        val overall = (parts.sumOf { it.first * it.second } / parts.sumOf { it.second }).roundToInt()

        val words = (0 until wordCount).map { w ->
            val mine = results.filter { letters[it.index].word == w }
            WordResult(mine.joinToString("") { it.glyph }, average(mine.map { it.score.toDouble() }), mine)
        }

        val issues = mutableListOf<Issue>()
        val missing = results.filter { it.missing }
        if (missing.isNotEmpty()) {
            val names = missing.take(3).joinToString(", ") { it.glyph }
            val what = if (missing.size == 1) "The $names is missing or hard to read." else "Some letters are missing or hard to read: $names."
            issues += Issue(IssueKind.INCOMPLETE, missing.first().index, "$what Write every letter of the line.")
        }
        val worst = results.filter { !it.missing }.minByOrNull { it.score }
        if (worst != null && worst.score < 60) {
            val word = words.getOrNull(letters[worst.index].word)?.text
            val where = if (word != null && word.length > 1) " in “$word”" else ""
            issues += Issue(IssueKind.OFF_PATH, worst.index, "Look at the ${worst.glyph}$where: follow its shape more closely.")
        }
        if (direction != null && direction < 50) {
            issues += Issue(IssueKind.STROKE_DIRECTION, -1, "Some strokes go the wrong way. Start at the dots and follow the arrows.")
        }
        if (baselineDev > 0.08) {
            issues += Issue(IssueKind.OFF_BASELINE, -1, "Keep every letter sitting on the baseline.")
        }
        if (sizeSpread > 0.18) {
            issues += Issue(IssueKind.UNEVEN_SIZE, -1, "Keep the small letters the same height, up to the dashed line.")
        } else if (heights.isNotEmpty() && abs(ln(meanHeight / 0.5)) > 0.3) {
            val kind = if (meanHeight > 0.5) IssueKind.TOO_BIG else IssueKind.TOO_SMALL
            val word = if (meanHeight > 0.5) "smaller" else "taller"
            issues += Issue(kind, -1, "Make the small letters $word: they should reach the dashed line.")
        }
        if (spacing != null && spacing < 60) {
            val tight = gaps.any { it < 0.15 }
            val text = if (tight) "Leave a clear space between words, about the width of an o."
            else "Keep the spaces between words the same size."
            issues += Issue(IssueKind.UNEVEN_SPACING, -1, text)
        }
        if (smoothness < 70) {
            issues += Issue(IssueKind.SHAKY, -1, "Your line is a little shaky. Try a steadier, more relaxed movement.")
        }

        return LineScore(overall, shape, size, baseline, spacing, smoothness, direction, words, issues)
    }

    private fun stretchSideways(ink: List<List<Vec>>, model: List<Vec>): List<List<Vec>> {
        val ub = Geometry.bounds(ink.flatten())
        val mb = Geometry.bounds(model)
        if (ub.width < 1e-6) return ink
        val sx = mb.width / ub.width
        return ink.map { s -> s.map { Vec((it.x - ub.minX) * sx + mb.minX, it.y) } }
    }

    private fun boundsOf(l: PlacedLetter) = Geometry.bounds(l.template.strokes.flatMap { it.toVecs() })

    /** Relative spread (standard deviation / mean) of positive values. */
    private fun spread(values: List<Double>): Double {
        if (values.size < 2) return 0.0
        val mean = values.average()
        if (mean <= 1e-9) return 0.0
        val variance = values.sumOf { (it - mean) * (it - mean) } / values.size
        return sqrt(variance) / mean
    }

    private fun average(values: List<Double>): Int = if (values.isEmpty()) 0 else values.average().roundToInt()

    private fun empty(letters: List<PlacedLetter>, message: String) = LineScore(
        overall = 0, shape = 0, size = 0, baseline = 0, spacing = null, smoothness = 0, direction = null,
        words = emptyList(),
        issues = listOf(Issue(IssueKind.INCOMPLETE, -1, message)),
    )
}
