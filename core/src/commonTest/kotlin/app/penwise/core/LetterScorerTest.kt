package app.penwise.core

import app.penwise.core.TestInk.ink
import app.penwise.core.TestInk.strokesOf
import app.penwise.core.TestInk.transform
import app.penwise.core.geometry.Vec
import app.penwise.core.model.InputKind
import app.penwise.core.model.Ink
import app.penwise.core.scoring.IssueKind
import app.penwise.core.scoring.LetterScorer
import app.penwise.core.scoring.Mode
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class LetterScorerTest {
    private val scorer = LetterScorer()

    private fun kinds(score: app.penwise.core.scoring.LetterScore) = score.issues.map { it.kind }

    @Test
    fun perfectLetterScoresHighInEveryMode() {
        for (template in listOf(TestInk.c, TestInk.o, TestInk.t, TestInk.a, TestInk.i)) {
            for (mode in Mode.entries) {
                val s = scorer.score(TestInk.perfect(template), template, mode)
                assertTrue(s.overall >= 95, "${template.glyph} in $mode scored ${s.overall}: ${s.issues}")
                assertTrue(s.issues.isEmpty(), "${template.glyph} in $mode had issues ${s.issues}")
                assertNull(s.tip)
            }
        }
    }

    @Test
    fun emptyInkScoresZero() {
        val s = scorer.score(Ink(emptyList()), TestInk.c, Mode.LEARN)
        assertEquals(0, s.overall)
        assertEquals(IssueKind.INCOMPLETE, s.issues.first().kind)
    }

    @Test
    fun reversedStrokeIsCaughtAsWrongDirection() {
        val reversed = strokesOf(TestInk.c).map { it.reversed() }
        val s = scorer.score(ink(reversed), TestInk.c, Mode.LEARN)
        assertEquals(false, s.strokes.single().directionOk)
        assertEquals(IssueKind.STROKE_DIRECTION, s.issues.first().kind)
        assertTrue(s.shape >= 95, "shape itself is right, got ${s.shape}")
        assertTrue(s.overall <= 70, "overall should drop, got ${s.overall}")
    }

    @Test
    fun swappedStrokesAreCaughtAsWrongOrder() {
        val swapped = strokesOf(TestInk.t).reversed()
        val s = scorer.score(ink(swapped), TestInk.t, Mode.PRACTICE)
        assertEquals(40, s.order)
        assertTrue(IssueKind.STROKE_ORDER in kinds(s))
        assertTrue(s.shape >= 95)
    }

    @Test
    fun loopStartedInTheWrongPlaceKeepsShapeButFlagsStart() {
        // An "o" drawn the right way round but started at the bottom.
        val o = TestInk.arc(0.26, 0.75, 0.22, 0.25, 270.0, 630.0, 36)
        val s = scorer.score(ink(listOf(o)), TestInk.o, Mode.PRACTICE)
        assertTrue(s.shape >= 90, "shape ${s.shape}")
        assertEquals(true, s.strokes.single().directionOk)
        assertEquals(false, s.strokes.single().startOk)
        assertTrue(IssueKind.START_POINT in kinds(s))
    }

    @Test
    fun clockwiseLoopIsWrongDirection() {
        val o = TestInk.arc(0.26, 0.75, 0.22, 0.25, 70.0, -290.0, 36)
        val s = scorer.score(ink(listOf(o)), TestInk.o, Mode.LEARN)
        assertEquals(false, s.strokes.single().directionOk)
    }

    @Test
    fun drawingFarFromThePathLowersShapeInLearnMode() {
        val moved = transform(strokesOf(TestInk.c)) { Vec(it.x + 0.15, it.y) }
        val s = scorer.score(ink(moved), TestInk.c, Mode.LEARN)
        assertTrue(s.shape < 40, "shape ${s.shape}")
        assertTrue(IssueKind.OFF_PATH in kinds(s))
    }

    @Test
    fun testModeForgivesPositionButJudgesSizeAndBaseline() {
        // Written 1.5x bigger and floating above the baseline.
        val big = transform(strokesOf(TestInk.c)) { Vec(it.x * 1.5 + 1.0, it.y * 1.5 - 0.6) }
        val s = scorer.score(ink(big), TestInk.c, Mode.TEST)
        assertTrue(s.shape >= 90, "shape ${s.shape}")
        assertTrue(s.size!! < 70, "size ${s.size}")
        assertTrue(IssueKind.TOO_BIG in kinds(s))
        assertTrue(IssueKind.OFF_BASELINE in kinds(s))
    }

    @Test
    fun shakyLineLowersSmoothness() {
        val calm = scorer.score(TestInk.perfect(TestInk.c), TestInk.c, Mode.PRACTICE)
        val shaky = scorer.score(ink(TestInk.shaky(strokesOf(TestInk.c), 0.025)), TestInk.c, Mode.PRACTICE)
        assertTrue(shaky.smoothness!! < calm.smoothness!!, "shaky ${shaky.smoothness} vs calm ${calm.smoothness}")
        assertTrue(IssueKind.SHAKY in kinds(shaky))
    }

    @Test
    fun halfALetterIsIncomplete() {
        val half = strokesOf(TestInk.o).map { it.take(it.size / 2) }
        val s = scorer.score(ink(half), TestInk.o, Mode.LEARN)
        assertTrue(IssueKind.INCOMPLETE in kinds(s), "${s.issues}")
        assertTrue(s.overall < 80, "overall ${s.overall}")
    }

    @Test
    fun alternateFormIsAccepted() {
        val oneStroke = TestInk.a.alternates.single().map { it.toVecs() }
        val s = scorer.score(ink(oneStroke), TestInk.a, Mode.PRACTICE)
        assertFalse(IssueKind.STROKE_COUNT in kinds(s), "${s.issues}")
        assertTrue(s.overall >= 90, "overall ${s.overall}")
    }

    @Test
    fun missingStrokeIsReportedAsStrokeCount() {
        val onlyStem = listOf(strokesOf(TestInk.t).first())
        val s = scorer.score(ink(onlyStem), TestInk.t, Mode.PRACTICE)
        assertEquals(IssueKind.STROKE_COUNT, s.issues.first().kind)
    }

    @Test
    fun dotsSkipDirectionChecks() {
        val i = strokesOf(TestInk.i).toMutableList()
        i[1] = i[1].reversed()
        val s = scorer.score(ink(i), TestInk.i, Mode.LEARN)
        assertNull(s.strokes[1].directionOk)
        assertTrue(s.issues.isEmpty(), "${s.issues}")
    }

    @Test
    fun fingerInputIsMoreForgiving() {
        val off = transform(strokesOf(TestInk.c)) { Vec(it.x + 0.07, it.y + 0.03) }
        val pen = scorer.score(ink(off, InputKind.STYLUS), TestInk.c, Mode.LEARN)
        val finger = scorer.score(ink(off, InputKind.FINGER), TestInk.c, Mode.LEARN)
        assertTrue(finger.overall > pen.overall, "finger ${finger.overall} vs pen ${pen.overall}")
    }
}
