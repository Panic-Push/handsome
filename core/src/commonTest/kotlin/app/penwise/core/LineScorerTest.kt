package app.penwise.core

import app.penwise.core.geometry.Vec
import app.penwise.core.model.Ink
import app.penwise.core.scoring.IssueKind
import app.penwise.core.scoring.LineLayout
import app.penwise.core.scoring.LineScorer
import app.penwise.core.scoring.PlacedLetter
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class LineScorerTest {
    private val scorer = LineScorer()
    private val templates = mapOf("c" to TestInk.c, "o" to TestInk.o, "a" to TestInk.a, "t" to TestInk.t, "i" to TestInk.i)

    /** Writes the placed letters perfectly, optionally moving each letter. */
    private fun write(letters: List<PlacedLetter>, move: (Int, Vec) -> Vec = { _, p -> p }): Ink =
        TestInk.ink(letters.flatMapIndexed { i, l ->
            l.letterTemplate.strokes.map { s -> s.toVecs().map { move(i, Vec(it.x + l.x, it.y)) } }
        })

    private fun kinds(ink: Ink, letters: List<PlacedLetter>, traced: Boolean) =
        (if (traced) scorer.scoreTraced(ink, letters) else scorer.scoreFree(ink, letters)).issues.map { it.kind }

    @Test
    fun layoutSplitsWordsAndSkipsPunctuation() {
        val placed = LineLayout.place("cat to.", templates, cursive = false)
        assertEquals(listOf("c", "a", "t", "t", "o"), placed.map { it.letterTemplate.glyph })
        assertEquals(listOf(0, 0, 0, 1, 1), placed.map { it.word })
        assertTrue(placed.zipWithNext().all { (a, b) -> b.x > a.x })
    }

    @Test
    fun perfectTracingScoresHigh() {
        val placed = LineLayout.place("coco", templates, cursive = false)
        val s = scorer.scoreTraced(write(placed), placed)
        assertTrue(s.overall >= 90, "overall ${s.overall}: ${s.issues}")
        assertTrue(s.issues.isEmpty(), "${s.issues}")
        assertEquals(4, s.words.single().letters.size)
    }

    @Test
    fun freeWritingIsJudgedAfterStretchingSideways() {
        val placed = LineLayout.place("cat oat", templates, cursive = false)
        // Written 30% wider and further right, but on the same lines.
        val ink = write(placed) { _, p -> Vec(p.x * 1.3 + 0.8, p.y) }
        val s = scorer.scoreFree(ink, placed)
        assertTrue(s.overall >= 85, "overall ${s.overall}: ${s.issues}")
        assertTrue(s.words.all { it.score >= 80 }, "${s.words}")
    }

    @Test
    fun aMissingLetterIsNamed() {
        val placed = LineLayout.place("coat", templates, cursive = false)
        val withoutA = placed.filter { it.letterTemplate.glyph != "a" }
        val s = scorer.scoreTraced(write(withoutA), placed)
        assertEquals(IssueKind.INCOMPLETE, s.issues.first().kind)
        assertTrue(s.tip!!.contains("a"), s.tip)
    }

    @Test
    fun aFloatingLineIsToldAboutTheBaseline() {
        val placed = LineLayout.place("coco", templates, cursive = false)
        val ink = write(placed) { _, p -> Vec(p.x, p.y - 0.2) }
        assertTrue(IssueKind.OFF_BASELINE in kinds(ink, placed, traced = false))
    }

    @Test
    fun unevenLetterHeightsAreCaught() {
        val placed = LineLayout.place("coco", templates, cursive = false)
        // The second and fourth letters are written much taller, still on the baseline.
        val ink = write(placed) { i, p -> if (i % 2 == 1) Vec(p.x, 1.0 - (1.0 - p.y) * 1.7) else p }
        assertTrue(IssueKind.UNEVEN_SIZE in kinds(ink, placed, traced = false))
    }

    @Test
    fun crampedWordsAreCaught() {
        val placed = LineLayout.place("co co co", templates, cursive = false)
        // Squash the first gap to nothing and widen the second.
        val ink = write(placed) { i, p ->
            when (placed[i].word) {
                0 -> Vec(p.x + 0.4, p.y)
                2 -> Vec(p.x + 0.8, p.y)
                else -> p
            }
        }
        assertTrue(IssueKind.UNEVEN_SPACING in kinds(ink, placed, traced = false))
    }
}
