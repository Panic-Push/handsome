package app.penwise.core

import app.penwise.core.TestInk.ink
import app.penwise.core.TestInk.strokesOf
import app.penwise.core.TestInk.transform
import app.penwise.core.geometry.Vec
import app.penwise.core.scoring.IssueKind
import app.penwise.core.scoring.LetterScorer
import app.penwise.core.scoring.Mode
import app.penwise.core.scoring.MotionDescriber
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class FeedbackWordingTest {
    private val scorer = LetterScorer()

    @Test
    fun describesPrintLettersInWords() {
        assertEquals(listOf("Start at the top right and curve left."), MotionDescriber.describe(TestInk.c))
        assertEquals(listOf("Start at the top and curve left."), MotionDescriber.describe(TestInk.o))
        assertEquals(
            listOf("Start at the top and go straight down.", "Then start on the left and go across to the right."),
            MotionDescriber.describe(TestInk.t),
        )
        assertEquals(listOf("Start at the top and go straight down.", "Then add the dot."), MotionDescriber.describe(TestInk.i))
    }

    @Test
    fun floatingLetterIsToldToComeDownToTheBaseline() {
        val floating = transform(strokesOf(TestInk.o)) { Vec(it.x, it.y - 0.2) }
        val s = scorer.score(ink(floating), TestInk.o, Mode.PRACTICE)
        val issue = s.issues.first { it.kind == IssueKind.OFF_BASELINE }
        assertEquals("The shape looks good. Bring the bottom of the o down to the baseline.", issue.message)
    }

    @Test
    fun directionAdviceDependsOnMode() {
        val reversed = strokesOf(TestInk.c).map { it.reversed() }
        val learn = scorer.score(ink(reversed), TestInk.c, Mode.LEARN).tip!!
        val test = scorer.score(ink(reversed), TestInk.c, Mode.TEST).tip!!
        assertEquals("The c goes the wrong way. Start at the green dot and follow the arrow.", learn)
        assertEquals("The c goes the wrong way. Start at the top right and curve left.", test)
    }

    @Test
    fun multiStrokeLettersNameTheStroke() {
        val t = strokesOf(TestInk.t).toMutableList()
        t[1] = t[1].reversed()
        val tip = scorer.score(ink(t), TestInk.t, Mode.LEARN).tip!!
        assertTrue(tip.startsWith("Stroke 2 goes the wrong way."), tip)
    }
}
