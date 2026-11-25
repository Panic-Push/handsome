package app.penwise.core.scoring

import app.penwise.core.geometry.Geometry
import app.penwise.core.geometry.Vec
import kotlin.math.abs

/**
 * Finds what to fix and words it for the mode, most important first.
 *
 * Learn points at the guide ("follow the arrow"), Practice at the faint
 * letter, and Test describes the motion in words because there is no guide.
 */
internal class IssueWriter(
    private val mode: Mode,
    private val glyph: String,
    private val templateStrokes: List<List<Vec>>,
    private val shapeScore: Int,
) {
    private val strokeCount = templateStrokes.size
    private val motions by lazy { MotionDescriber.describeStrokes(templateStrokes) }

    /** "The o" for one-stroke letters, "Stroke 2" otherwise. */
    private fun name(i: Int) = if (strokeCount == 1) "The $glyph" else "Stroke ${i + 1}"

    /** Credit a good shape before a smaller correction. */
    private val goodShape = if (shapeScore >= 85) "The shape looks good. " else ""

    private fun motion(i: Int) = motions.getOrNull(i) ?: ""

    /** "Add a dot above the stem.", "Add the crossbar.", or the stroke's motion. */
    private fun missingText(i: Int): String {
        val stroke = templateStrokes[i]
        if (Geometry.pathLength(stroke) < LetterScorer.TINY_STROKE) {
            val others = templateStrokes.filterIndexed { k, _ -> k != i }.flatten()
            val dotY = Geometry.bounds(stroke).center.y
            val above = others.isNotEmpty() && dotY < Geometry.bounds(others).minY
            return if (above) "Add a dot above the stem." else "Add the dot."
        }
        val b = Geometry.bounds(stroke)
        if (b.width > 2 * b.height) return "Add the crossbar."
        return "Add stroke ${i + 1}. ${motion(i)}"
    }

    fun write(
        userCount: Int,
        strokes: List<StrokeFeedback>,
        missingStrokes: List<Int>,
        orderCorrect: Boolean?,
        incomplete: Boolean,
        smoothness: Int?,
        sizeRatio: Double,
        baselineOffset: Double,
        tol: Tolerances,
    ): List<Issue> {
        val issues = mutableListOf<Issue>()

        // A left-out dot or crossbar is reported in every mode, with what to add.
        for (i in missingStrokes) {
            issues += Issue(IssueKind.MISSING_STROKE, i, missingText(i))
        }

        if (missingStrokes.isEmpty() && userCount != strokeCount && mode != Mode.TEST) {
            val noun = if (strokeCount == 1) "stroke" else "strokes"
            issues += Issue(IssueKind.STROKE_COUNT, -1, "Write the $glyph with $strokeCount $noun. You used $userCount.")
        }

        if (incomplete) {
            val how = if (mode == Mode.LEARN) "Follow the dots all the way to the end." else "Finish the whole letter."
            issues += Issue(IssueKind.INCOMPLETE, -1, "Part of the $glyph is missing. $how")
        }

        strokes.filter { it.directionOk == false }.forEach {
            val how = when (mode) {
                Mode.LEARN -> "Start at the green dot and follow the arrow."
                Mode.PRACTICE -> "Start at the green dot and go the other way."
                Mode.TEST -> motion(it.templateIndex)
            }
            issues += Issue(IssueKind.STROKE_DIRECTION, it.templateIndex, "${name(it.templateIndex)} goes the wrong way. $how")
        }

        if (orderCorrect == false && mode != Mode.LEARN) {
            val how = if (mode == Mode.TEST) motions.joinToString(" ") else "Follow the numbers on the dots."
            issues += Issue(IssueKind.STROKE_ORDER, -1, "${goodShape}The strokes are in the wrong order. $how")
        }

        if (mode != Mode.TEST) {
            strokes.filter { it.startOk == false && it.directionOk != false }.forEach {
                val what = if (strokeCount == 1) "the $glyph" else "stroke ${it.templateIndex + 1}"
                issues += Issue(IssueKind.START_POINT, it.templateIndex, "${goodShape}Start $what at the green dot.")
            }
        }

        strokes.filter { it.distance > tol.shape * 0.5 && it.templateIndex !in missingStrokes }.forEach {
            val how = when (mode) {
                Mode.LEARN -> "drifts off the dotted path. Slow down and stay on the dots."
                Mode.PRACTICE -> "drifts out of shape. Slow down and follow the faint letter."
                Mode.TEST -> "drifts out of shape. ${motion(it.templateIndex)}"
            }
            issues += Issue(IssueKind.OFF_PATH, it.templateIndex, "${name(it.templateIndex)} $how")
        }

        if (mode != Mode.LEARN) {
            if (abs(baselineOffset) > 0.08) {
                val text = if (baselineOffset < 0) "Bring the bottom of the $glyph down to the baseline."
                else "Lift the $glyph so it sits on the baseline."
                issues += Issue(IssueKind.OFF_BASELINE, -1, goodShape + text)
            }
            val top = Geometry.bounds(templateStrokes.flatten()).minY
            val line = if (top < 0.25) "top line" else "dashed middle line"
            if (sizeRatio > 1.25) {
                issues += Issue(IssueKind.TOO_BIG, -1, "${goodShape}Make the $glyph smaller. Its top should reach the $line.")
            }
            if (sizeRatio < 0.8) {
                issues += Issue(IssueKind.TOO_SMALL, -1, "${goodShape}Make the $glyph taller. Its top should reach the $line.")
            }
        }

        if (smoothness != null && smoothness < 70) {
            issues += Issue(IssueKind.SHAKY, -1, "${goodShape}Your line is a little shaky. Try a steadier, more relaxed movement.")
        }
        return issues
    }
}
