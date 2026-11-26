package app.penwise.core.plan

/** What a plan activity asks the app to open. */
enum class ActivityKind {
    /** Guided lesson for letters (watch, trace, train). */
    LETTER_LESSON,
    /** Letters written over a faint model. */
    LETTER_PRACTICE,
    /** Letters written from memory. */
    LETTER_TEST,
    /** Words from the word list, written on lines. */
    WORDS,
    /** A sentence on the sentence worksheet. */
    SENTENCE,
}

/**
 * One item of today's plan. [focus] tells the screen what to emphasise (for
 * example highlight the baseline for a BASELINE drill); null means none.
 */
data class PlanActivity(
    /** Stable key, unique within the day ("id" would be renamed in the Swift bridge). */
    val key: String,
    val kind: ActivityKind,
    val title: String,
    val detail: String,
    val letters: List<String>,
    val minutes: Int,
    val focus: Skill?,
)

data class DailyPlan(
    val day: Int,
    val minutes: Int,
    val focus: List<Skill>,
    val activities: List<PlanActivity>,
    /** Suggest a new assessment after this many days of practice. */
    val reassessAfterDays: Int,
)

/**
 * Builds a day's plan from the assessment report: a warm-up, practice aimed
 * at the weakest skills and letters, and a short writing task. The plan
 * changes from day to day ([day] is 0 on the first day) so practice stays fresh.
 */
object PlanBuilder {
    /** Letters in teaching order, used when no weak letters were found. */
    private val teachingOrder = "coadltigqjynmhrbpesfukvwxz".map { it.toString() }

    fun build(report: AssessmentReport, minutesPerDay: Int, day: Int): DailyPlan {
        val minutes = minutesPerDay.coerceIn(5, 30)
        val focus = report.focus.ifEmpty { listOf(Skill.SHAPE) }
        val skill = focus[day % focus.size]
        val weak = report.weakLetters.ifEmpty { teachingOrder }
        val todaysLetters = rotate(weak, day * 2).take(if (minutes >= 15) 3 else 2)

        // Time split; the focus practice gets whatever is left, so the plan
        // always adds up to exactly the chosen minutes.
        val warmupMinutes = if (minutes >= 15) 4 else if (minutes >= 10) 3 else 2
        val memoryMinutes = if (minutes >= 10) 2 else 0
        val sentenceMinutes = if (minutes >= 15) 4 else 0
        val focusMinutes = minutes - warmupMinutes - memoryMinutes - sentenceMinutes

        val activities = mutableListOf<PlanActivity>()
        // Warm-up: the weakest letter of the day.
        activities += PlanActivity(
            key = "d$day-warmup",
            kind = if (report.overall < 60) ActivityKind.LETTER_LESSON else ActivityKind.LETTER_PRACTICE,
            title = "Warm up with ${todaysLetters.first()}",
            detail = "Trace it slowly, then write it with a faint guide.",
            letters = listOf(todaysLetters.first()),
            minutes = warmupMinutes,
            focus = null,
        )
        // Main practice: aimed at today's focus skill.
        activities += focusActivity(skill, todaysLetters, day, focusMinutes)
        // Memory check on the day's letters.
        if (memoryMinutes > 0) {
            activities += PlanActivity(
                key = "d$day-memory",
                kind = ActivityKind.LETTER_TEST,
                title = "From memory: ${todaysLetters.joinToString(" ")}",
                detail = "Write each one without a guide.",
                letters = todaysLetters,
                minutes = memoryMinutes,
                focus = null,
            )
        }
        // Real writing to finish.
        if (sentenceMinutes > 0) {
            activities += PlanActivity(
                key = "d$day-sentence",
                kind = ActivityKind.SENTENCE,
                title = "Write a sentence",
                detail = "Keep it even: same size, steady on the line.",
                letters = emptyList(),
                minutes = sentenceMinutes,
                focus = if (Skill.SPACING in focus) Skill.SPACING else null,
            )
        }
        return DailyPlan(day, minutes, focus, activities, reassessAfterDays = 14)
    }

    /**
     * The same plan from plain values (as saved by the app): [focusSkills] are
     * Skill names such as "BASELINE"; unknown names are ignored.
     */
    fun buildFor(overall: Int, focusSkills: List<String>, weakLetters: List<String>, minutesPerDay: Int, day: Int): DailyPlan {
        val focus = focusSkills.mapNotNull { name -> Skill.entries.firstOrNull { it.name == name } }
        val report = AssessmentReport(
            overall = overall, skills = emptyList(), focus = focus, strengths = emptyList(), letters = emptyList(),
            weakLetters = weakLetters, lettersPerMinute = null, summary = "",
        )
        return build(report, minutesPerDay, day)
    }

    private fun focusActivity(skill: Skill, letters: List<String>, day: Int, minutes: Int): PlanActivity {
        val id = "d$day-focus-${skill.name.lowercase()}"
        return when (skill) {
            Skill.SHAPE, Skill.DIRECTION, Skill.START, Skill.ORDER -> PlanActivity(
                id, ActivityKind.LETTER_LESSON, "${skill.title}: ${letters.joinToString(" ")}",
                when (skill) {
                    Skill.DIRECTION -> "Follow the arrows: every stroke the right way round."
                    Skill.START -> "Start every letter at the green dot."
                    Skill.ORDER -> "Write the strokes in the numbered order."
                    else -> "Trace, then train each letter until the shape feels natural."
                },
                letters, minutes, skill,
            )
            Skill.SIZE -> PlanActivity(
                id, ActivityKind.WORDS, "Even size: words",
                "Keep every small letter touching the dashed line.", letters, minutes, skill,
            )
            Skill.BASELINE -> PlanActivity(
                id, ActivityKind.WORDS, "On the line: words",
                "Rest every letter on the baseline.", letters, minutes, skill,
            )
            Skill.SPACING -> PlanActivity(
                id, ActivityKind.SENTENCE, "Spacing: a sentence",
                "Leave about one o between words.", emptyList(), minutes, skill,
            )
            Skill.SMOOTHNESS -> PlanActivity(
                id, ActivityKind.LETTER_PRACTICE, "Smooth lines: ${letters.joinToString(" ")}",
                "Write a little slower with a relaxed grip.", letters, minutes, skill,
            )
            Skill.SPEED -> PlanActivity(
                id, ActivityKind.WORDS, "Speed: words",
                "Write each word in one flowing go, then a little faster.", letters, minutes, skill,
            )
        }
    }

    private fun rotate(list: List<String>, by: Int): List<String> {
        if (list.isEmpty()) return list
        val k = by % list.size
        return list.drop(k) + list.take(k)
    }
}
