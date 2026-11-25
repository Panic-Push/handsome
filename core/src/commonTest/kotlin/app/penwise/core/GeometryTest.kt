package app.penwise.core

import app.penwise.core.geometry.Geometry
import app.penwise.core.geometry.Vec
import app.penwise.core.scoring.LetterScorer
import kotlin.math.abs
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class GeometryTest {
    @Test
    fun resampleGivesEvenlySpacedPoints() {
        val p = Geometry.resample(listOf(Vec(0.0, 0.0), Vec(1.0, 0.0), Vec(1.0, 1.0)), 5)
        assertEquals(5, p.size)
        assertEquals(Vec(0.0, 0.0), p.first())
        assertEquals(Vec(1.0, 1.0), p.last())
        assertTrue(abs(p[2].x - 1.0) < 1e-9 && abs(p[2].y) < 1e-9, "middle point ${p[2]}")
    }

    @Test
    fun resampleHandlesASinglePoint() {
        assertEquals(List(4) { Vec(2.0, 3.0) }, Geometry.resample(listOf(Vec(2.0, 3.0)), 4))
    }

    @Test
    fun chamferIgnoresDirection() {
        val a = Geometry.resample(listOf(Vec(0.0, 0.0), Vec(1.0, 0.0)), 20)
        assertTrue(Geometry.chamfer(a, a.reversed()) < 1e-9)
    }

    @Test
    fun scoreMappingIsMonotonic() {
        assertEquals(100, LetterScorer.toScore(0.0, 0.1))
        assertEquals(100, LetterScorer.toScore(0.01, 0.1))
        assertEquals(0, LetterScorer.toScore(0.2, 0.1))
        assertTrue(LetterScorer.toScore(0.04, 0.1) > LetterScorer.toScore(0.06, 0.1))
    }

    @Test
    fun bestAssignmentFindsSwap() {
        val cost = arrayOf(doubleArrayOf(5.0, 1.0), doubleArrayOf(1.0, 5.0))
        assertEquals(listOf(1, 0), LetterScorer.bestAssignment(cost).toList())
    }
}
