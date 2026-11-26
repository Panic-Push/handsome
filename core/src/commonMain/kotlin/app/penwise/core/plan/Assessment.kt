package app.penwise.core.plan

import app.penwise.core.scoring.IssueKind
import app.penwise.core.scoring.LetterScore
import app.penwise.core.scoring.LineScore
import kotlin.math.roundToInt

/** The handwriting skills the report measures and the plan trains. */
enum class Skill(val title: String, val advice: String) {
    SHAPE("Letter shape", "Letters drift away from their correct shapes."),
    DIRECTION("Stroke direction", "Some strokes are drawn the wrong way round."),
    START("Starting points", "Letters often start in the wrong place."),
    ORDER("Stroke order", "Strokes are written in an unusual order."),
    SIZE("Even size", "Letters change size within a word."),
    BASELINE("Sitting on the line", "Letters float above or dip below the baseline."),
    SPACING("Word spacing", "Gaps between words are uneven."),
    SMOOTHNESS("Smooth lines", "Lines look a little shaky."),
    SPEED("Writing speed", "Writing is slow, which can make it tiring."),
}

/** What the starting assessment asks the learner to write. */
data class AssessmentTask(
    val id: String,
    /** A single letter (scored with the letter scorer) or a word/sentence. */
    val text: String,
    val isLine: Boolean,
    val prompt: String,
)

object AssessmentPlan {
    /** Letters from different families, a word, then a short sentence, all from memory. */
    val tasks: List<AssessmentTask> = listOf(
        AssessmentTask("letter-a", "a", false, "Write a lowercase a."),
        AssessmentTask("letter-e", "e", false, "Write a lowercase e."),
        AssessmentTask("letter-g", "g", false, "Write a lowercase g."),
        AssessmentTask("letter-k", "k", false, "Write a lowercase k."),
        AssessmentTask("letter-s", "s", false, "Write a lowercase s."),
        AssessmentTask("letter-t", "t", false, "Write a lowercase t."),
        AssessmentTask("word", "handwriting", true, "Write the word: handwriting"),
        AssessmentTask("sentence", "Quick foxes jump over a lazy dog.", true,
            "Write this sentence at your normal speed: Quick foxes jump over a lazy dog."),
    )
}

data class SkillScore(val skill: Skill, val score: Int)

data class LetterAssessment(val glyph: String, val score: Int, val issue: String?)

data class AssessmentReport(
    val overall: Int,
    /** Every measured skill, weakest first. */
    val skills: List<SkillScore>,
    /** Up to three skills to work on (below 75), weakest first. */
    val focus: List<Skill>,
    /** Skills at 85 or above. */
    val strengths: List<Skill>,
    val letters: List<LetterAssessment>,
    /** Letters that scored below 70, weakest first. */
    val weakLetters: List<String>,
    val lettersPerMinute: Int?,
    /** One plain-language sentence summing up the result. */
    val summary: String,
)

/**
 * Collects the assessment results and turns them into a report. Feed it every
 * scored task in any order, then call [build].
 */
class AssessmentReportBuilder {
    private val samples = mutableMapOf<Skill, MutableList<Int>>()
    private val letters = mutableListOf<LetterAssessment>()
    private val overalls = mutableListOf<Int>()
    private var timedLetters = 0
    private var timedSeconds = 0.0

    private fun add(skill: Skill, value: Int?) {
        if (value != null) samples.getOrPut(skill) { mutableListOf() } += value
    }

    fun addLetter(glyph: String, score: LetterScore) {
        overalls += score.overall
        letters += LetterAssessment(glyph, score.overall, score.issues.firstOrNull()?.kind?.name)
        add(Skill.SHAPE, score.shape)
        add(Skill.DIRECTION, score.direction)
        add(Skill.START, score.start)
        add(Skill.ORDER, score.order)
        add(Skill.SIZE, score.size)
        add(Skill.BASELINE, score.baseline)
        add(Skill.SMOOTHNESS, score.smoothness)
    }

    /**
     * Adds a word or sentence. [seconds] is how long it took to write (first
     * touch to last lift), used for speed; pass a negative value if unknown.
     */
    fun addLine(text: String, score: LineScore, seconds: Double) {
        overalls += score.overall
        add(Skill.SHAPE, score.shape)
        add(Skill.SIZE, score.size)
        add(Skill.BASELINE, score.baseline)
        add(Skill.SPACING, score.spacing)
        add(Skill.SMOOTHNESS, score.smoothness)
        for (word in score.words) {
            for (l in word.letters) {
                if (l.score < 70) letters += LetterAssessment(l.glyph, l.score, IssueKind.OFF_PATH.name)
            }
        }
        val count = text.count { it.isLetterOrDigit() }
        if (seconds > 0 && count > 0) {
            timedLetters += count
            timedSeconds += seconds
        }
    }

    fun build(): AssessmentReport {
        val lpm = if (timedSeconds > 0) (timedLetters / (timedSeconds / 60.0)).roundToInt() else null
        val skillScores = samples.map { (skill, values) -> SkillScore(skill, values.average().roundToInt()) }.toMutableList()
        if (lpm != null) skillScores += SkillScore(Skill.SPEED, speedScore(lpm))
        val skills = skillScores.sortedBy { it.score }
        val focus = skills.filter { it.score < 75 }.take(3).map { it.skill }
        val strengths = skills.filter { it.score >= 85 }.map { it.skill }.reversed()
        val weak = letters.filter { it.score < 70 }.sortedBy { it.score }.map { it.glyph }.distinct()
        val overall = if (overalls.isEmpty()) 0 else overalls.average().roundToInt()
        return AssessmentReport(
            overall = overall,
            skills = skills,
            focus = focus,
            strengths = strengths,
            letters = letters.distinctBy { it.glyph },
            weakLetters = weak,
            lettersPerMinute = lpm,
            summary = summary(overall, focus, strengths),
        )
    }

    /** Adults usually write 60-120 letters a minute; below 30 is slow. */
    private fun speedScore(lpm: Int): Int = when {
        lpm >= 60 -> 100
        lpm <= 15 -> 30
        else -> 30 + ((lpm - 15) * 70) / 45
    }

    private fun summary(overall: Int, focus: List<Skill>, strengths: List<Skill>): String {
        val good = strengths.firstOrNull()?.title?.lowercase()
        val work = focus.take(2).map { it.title.lowercase() }
        return when {
            focus.isEmpty() -> "Your handwriting is in good shape. Practice will keep it neat and fast."
            good != null -> "Your ${good} is a strength. The plan focuses on ${work.joinToString(" and ")}."
            overall < 50 -> "A fresh start will help: the plan begins with letter shapes and builds from there."
            else -> "The plan focuses on ${work.joinToString(" and ")}."
        }
    }
}
