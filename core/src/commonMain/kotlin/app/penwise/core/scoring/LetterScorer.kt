package app.penwise.core.scoring

import app.penwise.core.geometry.Geometry
import app.penwise.core.geometry.Vec
import app.penwise.core.model.Ink
import app.penwise.core.template.LetterTemplate
import kotlin.math.abs
import kotlin.math.ln
import kotlin.math.roundToInt

/**
 * Scores one handwritten letter against its template.
 *
 * Steps: resample strokes, match user strokes to template strokes, then measure
 * shape (distance both ways between paths), direction (tangent agreement), start points, order,
 * smoothness, and in Practice/Test also size and baseline. The best-scoring
 * accepted form of the letter is used, so alternative forms are not punished.
 */
class LetterScorer(private val samplesPerStroke: Int) {

    /** Default settings. (Swift cannot see Kotlin default arguments, so this is explicit.) */
    constructor() : this(32)

    fun score(ink: Ink, template: LetterTemplate, mode: Mode): LetterScore {
        val user = ink.strokes
            .map { s -> s.points.map { Vec(it.x, it.y) } }
            .filter { it.isNotEmpty() }
        val tol = Tolerances.of(mode, ink.input)
        if (user.isEmpty()) return emptyScore(template)

        val forms = listOf(template.strokes) + template.alternates
        return forms
            .map { form -> scoreForm(user, form.map { it.toVecs() }, mode, tol, template.glyph) }
            .maxByOrNull { it.overall }!!
    }

    private fun scoreForm(
        rawUser: List<List<Vec>>,
        rawTemplate: List<List<Vec>>,
        mode: Mode,
        tol: Tolerances,
        glyph: String,
    ): LetterScore {
        // Outside Learn, judge shape after fitting the letter onto the template:
        // size and baseline have their own scores, so position is not counted twice.
        val shapeUser = if (mode == Mode.LEARN) rawUser else fitOnto(rawUser, rawTemplate)

        val u = shapeUser.map { Geometry.resample(it, samplesPerStroke) }
        val t = rawTemplate.map { Geometry.resample(it, samplesPerStroke) }
        val tLengths = rawTemplate.map { Geometry.pathLength(it) }
        val uAll = u.flatten()
        val tAll = t.flatten()

        val strokes = mutableListOf<StrokeFeedback>()
        var orderCorrect: Boolean? = null
        var directionScore: Int?
        var startScore: Int?

        if (u.size == t.size) {
            val cost = Array(t.size) { i -> DoubleArray(u.size) { j -> Geometry.shapeDistance(u[j], t[i]) } }
            val perm = bestAssignment(cost)
            orderCorrect = perm.indices.all { perm[it] == it }
            for (i in t.indices) {
                val j = perm[i]
                val tiny = tLengths[i] < TINY_STROKE
                val dist = cost[i][j]
                val dirOk = if (tiny) null else Geometry.directionAgreement(listOf(u[j]), listOf(t[i])) >= 0.6
                val startOk = if (tiny) null else u[j].first().distanceTo(t[i].first()) <= tol.start
                strokes += StrokeFeedback(i, j, dist, toScore(dist, tol.shape), dirOk, startOk)
            }
            directionScore = fractionScore(strokes.map { it.directionOk }, tLengths)
            startScore = fractionScore(strokes.map { it.startOk }, tLengths)
        } else {
            // Different number of strokes (joined or broken strokes). Judge the
            // letter as a whole and report coverage per template stroke.
            for (i in t.indices) {
                val dist = Geometry.directedDistance(t[i], uAll)
                strokes += StrokeFeedback(i, -1, dist, toScore(dist, tol.shape), null, null)
            }
            val agreement = Geometry.directionAgreement(u, t)
            directionScore = (Geometry.clamp01((agreement - 0.5) / 0.4) * 100).roundToInt()
            startScore = if (uAll.first().distanceTo(tAll.first()) <= tol.start) 100 else 0
        }

        val shapeScore = if (u.size == t.size) {
            weightedAverage(strokes.map { it.shapeScore.toDouble() }, tLengths)
        } else {
            toScore(Geometry.shapeDistance(uAll, tAll), tol.shape)
        }

        val missing = Geometry.directedDistance(tAll, uAll)
        val extra = Geometry.directedDistance(uAll, tAll)
        val incomplete = missing > tol.shape * 0.6 && missing > extra * 2

        val orderScore: Int? = when {
            mode == Mode.LEARN -> null
            orderCorrect == true -> 100
            orderCorrect == false -> 40
            mode == Mode.TEST -> null // adults often join strokes; don't punish it
            else -> 60
        }

        val smoothness = if (mode == Mode.LEARN) null else smoothnessScore(rawUser, tol)

        var sizeScore: Int? = null
        var baselineScore: Int? = null
        var sizeRatio = 1.0
        var baselineOffset = 0.0
        if (mode != Mode.LEARN) {
            val ub = Geometry.bounds(rawUser.flatten())
            val tb = Geometry.bounds(rawTemplate.flatten())
            sizeRatio = if (tb.height > 0.05 && ub.height > 1e-6) ub.height / tb.height
            else if (ub.diagonal > 1e-6) ub.diagonal / tb.diagonal else 1.0
            sizeScore = toScore(abs(ln(sizeRatio)), tol.sizeLog)
            baselineOffset = ub.maxY - tb.maxY
            baselineScore = toScore(abs(baselineOffset), tol.baseline)
        }

        if (mode == Mode.LEARN) directionScore = directionScore ?: 100
        if (mode == Mode.TEST) startScore = null

        val parts = mapOf(
            "shape" to shapeScore, "order" to orderScore, "direction" to directionScore,
            "start" to startScore, "smoothness" to smoothness, "size" to sizeScore, "baseline" to baselineScore,
        )
        var sum = 0.0
        var weight = 0.0
        for ((name, w) in Weights.of(mode)) {
            val v = parts[name] ?: continue
            sum += v * w
            weight += w
        }
        val overall = if (weight == 0.0) 0 else (sum / weight).roundToInt()

        val issues = IssueWriter(
            mode = mode,
            glyph = glyph,
            templateStrokes = rawTemplate,
            shapeScore = shapeScore,
        ).write(u.size, strokes, orderCorrect, incomplete, smoothness, sizeRatio, baselineOffset, tol)

        return LetterScore(
            overall = overall,
            shape = shapeScore,
            order = orderScore,
            direction = directionScore,
            start = startScore,
            smoothness = smoothness,
            size = sizeScore,
            baseline = baselineScore,
            strokes = strokes,
            issues = issues,
        )
    }

    private fun smoothnessScore(user: List<List<Vec>>, tol: Tolerances): Int {
        var sum = 0.0
        var weight = 0.0
        for (s in user) {
            val len = Geometry.pathLength(s)
            if (len < TINY_STROKE) continue
            sum += Geometry.jitter(s) * len
            weight += len
        }
        if (weight == 0.0) return 100
        return toScore(sum / weight, tol.jitter)
    }

    /** Scales and moves the user's letter so its bounding box matches the template's. */
    private fun fitOnto(user: List<List<Vec>>, template: List<List<Vec>>): List<List<Vec>> {
        val ub = Geometry.bounds(user.flatten())
        val tb = Geometry.bounds(template.flatten())
        if (ub.diagonal < 1e-9) return user
        val s = tb.diagonal / ub.diagonal
        return user.map { stroke -> stroke.map { (it - ub.center) * s + tb.center } }
    }

    private fun emptyScore(template: LetterTemplate) = LetterScore(
        overall = 0, shape = 0, order = null, direction = null, start = null,
        smoothness = null, size = null, baseline = null, strokes = emptyList(),
        issues = listOf(Issue(IssueKind.INCOMPLETE, -1, "Nothing was written yet. Write the letter ${template.glyph}.")),
    )

    companion object {
        /** Strokes shorter than this (dots, e.g. on i and j) skip direction and start checks. */
        const val TINY_STROKE = 0.06

        /** Distance → 0..100. Within 15% of the tolerance counts as perfect. */
        fun toScore(distance: Double, tolerance: Double): Int {
            val free = tolerance * 0.15
            val v = 1.0 - (distance - free) / (tolerance - free)
            return (Geometry.clamp01(v) * 100).roundToInt()
        }

        private fun weightedAverage(values: List<Double>, weights: List<Double>): Int {
            var s = 0.0
            var w = 0.0
            for (i in values.indices) {
                val wi = maxOf(weights[i], 0.02)
                s += values[i] * wi
                w += wi
            }
            return if (w == 0.0) 0 else (s / w).roundToInt()
        }

        private fun fractionScore(flags: List<Boolean?>, weights: List<Double>): Int? {
            var ok = 0.0
            var w = 0.0
            for (i in flags.indices) {
                val f = flags[i] ?: continue
                w += weights[i]
                if (f) ok += weights[i]
            }
            return if (w == 0.0) null else (ok / w * 100).roundToInt()
        }

        /** perm[i] = user stroke matched to template stroke i, minimising total cost. */
        internal fun bestAssignment(cost: Array<DoubleArray>): IntArray {
            val n = cost.size
            if (n == 0) return IntArray(0)
            if (n > 7) return IntArray(n) { it } // too many to brute-force; assume order
            var best = IntArray(n) { it }
            var bestCost = Double.MAX_VALUE
            val current = IntArray(n)
            val used = BooleanArray(n)
            fun search(i: Int, acc: Double) {
                if (acc >= bestCost) return
                if (i == n) { bestCost = acc; best = current.copyOf(); return }
                for (j in 0 until n) {
                    if (used[j]) continue
                    used[j] = true; current[i] = j
                    search(i + 1, acc + cost[i][j])
                    used[j] = false
                }
            }
            // Try the written order first so ties keep it.
            search(0, 0.0)
            val identity = (0 until n).sumOf { cost[it][it] }
            if (identity <= bestCost + 1e-9) return IntArray(n) { it }
            return best
        }
    }
}
