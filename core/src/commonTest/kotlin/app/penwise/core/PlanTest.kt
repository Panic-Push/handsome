package app.penwise.core

import app.penwise.core.plan.ActivityKind
import app.penwise.core.plan.AssessmentPlan
import app.penwise.core.plan.AssessmentReportBuilder
import app.penwise.core.plan.PlanBuilder
import app.penwise.core.plan.Skill
import app.penwise.core.scoring.Issue
import app.penwise.core.scoring.IssueKind
import app.penwise.core.scoring.LetterResult
import app.penwise.core.scoring.LetterScore
import app.penwise.core.scoring.LineScore
import app.penwise.core.scoring.WordResult
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class PlanTest {
    private fun letter(overall: Int, baseline: Int = 95, size: Int = 95, direction: Int = 100) = LetterScore(
        overall = overall, shape = overall, order = 100, direction = direction, start = 100, smoothness = 95,
        size = size, baseline = baseline, strokes = emptyList(),
        issues = if (overall < 70) listOf(Issue(IssueKind.OFF_PATH, 0, "x")) else emptyList(),
    )

    private fun line(overall: Int, spacing: Int?, baseline: Int = 90) = LineScore(
        overall = overall, shape = overall, size = 90, baseline = baseline, spacing = spacing, smoothness = 90,
        direction = null,
        words = listOf(WordResult("dog", overall, listOf(LetterResult(0, "d", overall, false)))),
        issues = emptyList(),
    )

    @Test
    fun assessmentHasLettersAWordAndASentence() {
        val tasks = AssessmentPlan.tasks
        assertTrue(tasks.count { !it.isLine } >= 5)
        assertTrue(tasks.last().isLine && tasks.last().text.contains(" "))
    }

    @Test
    fun reportFindsTheWeakestSkillsAndLetters() {
        val b = AssessmentReportBuilder()
        b.addLetter("a", letter(92))
        b.addLetter("g", letter(55, baseline = 40))
        b.addLetter("k", letter(88, baseline = 50))
        b.addLine("dog", line(80, spacing = null, baseline = 45), 2.0)
        b.addLine("Quick dog jumps.", line(78, spacing = 40, baseline = 50), 12.0)
        val r = b.build()
        assertEquals(Skill.SPACING, r.focus.first(), "${r.skills}")
        assertTrue(Skill.BASELINE in r.focus, "${r.focus}")
        assertEquals("g", r.weakLetters.first())
        assertTrue(r.lettersPerMinute!! in 60..80, "lpm ${r.lettersPerMinute}")
        assertTrue(r.summary.isNotBlank())
        assertTrue(r.skills.zipWithNext().all { (a, b) -> a.score <= b.score }, "weakest first")
    }

    @Test
    fun goodHandwritingHasNoFocusAndStillGetsAPlan() {
        val b = AssessmentReportBuilder()
        listOf("a", "e", "g").forEach { b.addLetter(it, letter(96)) }
        val r = b.build()
        assertTrue(r.focus.isEmpty())
        val plan = PlanBuilder.build(r, 10, day = 0)
        assertTrue(plan.activities.isNotEmpty())
        assertTrue(plan.activities.sumOf { it.minutes } <= 10)
    }

    @Test
    fun planTargetsTheFocusSkillAndFitsTheTime() {
        val b = AssessmentReportBuilder()
        b.addLetter("g", letter(60, baseline = 40))
        b.addLetter("s", letter(65, baseline = 45))
        val r = b.build()
        for (minutes in listOf(5, 10, 15, 20)) {
            val plan = PlanBuilder.build(r, minutes, day = 0)
            assertEquals(minutes, plan.activities.sumOf { it.minutes }, "$minutes: ${plan.activities}")
            assertTrue(plan.activities.any { it.focus == Skill.BASELINE && it.kind == ActivityKind.WORDS })
            assertTrue(plan.activities.first().letters.first() in listOf("g", "s"))
        }
    }

    @Test
    fun planChangesFromDayToDay() {
        val b = AssessmentReportBuilder()
        b.addLetter("g", letter(50, baseline = 40, size = 50))
        b.addLetter("s", letter(55, baseline = 45, size = 55))
        b.addLetter("k", letter(60, direction = 40))
        val r = b.build()
        val days = (0..3).map { PlanBuilder.build(r, 15, it) }
        assertTrue(days.map { it.activities[1].focus }.toSet().size > 1, "focus should rotate")
        assertTrue(days.flatMap { d -> d.activities.map { it.id } }.toSet().size == days.sumOf { it.activities.size }, "ids are unique per day")
    }

    @Test
    fun planFromSavedValuesMatchesThePlanFromTheReport() {
        val b = AssessmentReportBuilder()
        b.addLetter("g", letter(60, baseline = 40))
        val r = b.build()
        val direct = PlanBuilder.build(r, 10, 2)
        val saved = PlanBuilder.buildFor(r.overall, r.focus.map { it.name }, r.weakLetters, 10, 2)
        assertEquals(direct.activities.map { it.id }, saved.activities.map { it.id })
    }
}
