package app.penwise.core.scoring

import app.penwise.core.geometry.Bounds
import app.penwise.core.geometry.Geometry
import app.penwise.core.geometry.Vec
import app.penwise.core.template.LetterTemplate
import kotlin.math.abs
import kotlin.math.atan2

/**
 * Turns a letter's strokes into plain words, e.g.
 * "Start at the top right and curve left." Used in Test mode, where there is
 * no dotted guide to point at.
 */
object MotionDescriber {

    fun describe(template: LetterTemplate): List<String> = describeStrokes(template.strokes.map { it.toVecs() })

    fun describeStrokes(strokes: List<List<Vec>>): List<String> {
        val all = strokes.flatten()
        if (all.isEmpty()) return emptyList()
        val box = Geometry.bounds(all)
        return strokes.mapIndexed { i, s -> describeStroke(s, box, i) }
    }

    private fun describeStroke(s: List<Vec>, box: Bounds, index: Int): String {
        if (s.isEmpty() || Geometry.pathLength(s) < LetterScorer.TINY_STROKE) {
            return if (index == 0) "Make the dot." else "Then add the dot."
        }
        val lead = if (index == 0) "Start" else "Then start"
        return "$lead ${position(s.first(), box)} and ${motion(s)}."
    }

    private fun position(p: Vec, box: Bounds): String {
        val rx = if (box.width < 1e-6) 0.5 else (p.x - box.minX) / box.width
        val ry = if (box.height < 1e-6) 0.5 else (p.y - box.minY) / box.height
        val v = when {
            ry <= 0.35 -> "top"
            ry >= 0.65 -> "bottom"
            else -> "middle"
        }
        val h = when {
            rx <= 0.3 -> "left"
            rx >= 0.7 -> "right"
            else -> ""
        }
        return when {
            v == "middle" && h.isEmpty() -> "in the middle"
            v == "middle" -> "on the $h"
            h.isEmpty() -> "at the $v"
            else -> "at the $v $h"
        }
    }

    private fun motion(s: List<Vec>): String {
        val r = Geometry.resample(s, 40)
        val d = r[6] - r[0] // direction over the first 15% of the stroke
        var turn = 0.0      // how much it bends over the first 40%
        for (k in 1 until 16) {
            val a = r[k] - r[k - 1]
            val b = r[k + 1] - r[k]
            if (a.length() < 1e-9 || b.length() < 1e-9) continue
            turn += atan2(a.x * b.y - a.y * b.x, a.dot(b))
        }
        val curved = abs(turn) > 0.6
        val verb = if (curved) "curve" else "go"
        val vertical = abs(d.y) > 1.5 * abs(d.x)
        val horizontal = abs(d.x) > 1.5 * abs(d.y)
        val up = d.y < 0
        val left = d.x < 0
        return when {
            vertical && !up -> if (curved) "curve down" else "go straight down"
            vertical -> "$verb up"
            horizontal && left -> "$verb left"
            horizontal -> if (curved) "curve right" else "go across to the right"
            else -> "$verb ${if (up) "up" else "down"} to the ${if (left) "left" else "right"}"
        }
    }
}
