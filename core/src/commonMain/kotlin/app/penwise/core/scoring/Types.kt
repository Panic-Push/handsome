package app.penwise.core.scoring

import app.penwise.core.model.InputKind

/** The three learning modes. */
enum class Mode {
    /** Trace over the dotted letter. Judges path, start point and direction. */
    LEARN,

    /** Write over a faint model. Adds stroke order, smoothness, size and baseline; shape is judged after fitting. */
    PRACTICE,

    /** Free writing on ruled lines. Shape is judged after scaling, size and baseline separately. */
    TEST,
}

enum class IssueKind {
    STROKE_COUNT,
    INCOMPLETE,
    STROKE_DIRECTION,
    STROKE_ORDER,
    START_POINT,
    OFF_PATH,
    OFF_BASELINE,
    TOO_BIG,
    TOO_SMALL,
    SHAKY,
}

/**
 * One thing to fix. [strokeIndex] is the 0-based template stroke it concerns,
 * or -1 when it applies to the whole letter. [message] is default English
 * text; apps may localise from [kind] and [strokeIndex] instead.
 */
data class Issue(
    val kind: IssueKind,
    val strokeIndex: Int,
    val message: String,
)

/** How one template stroke was written. -1 / null mean "not judged". */
data class StrokeFeedback(
    val templateIndex: Int,
    val userIndex: Int,
    /** Average distance from the correct path, in line units. */
    val distance: Double,
    val shapeScore: Int,
    val directionOk: Boolean?,
    val startOk: Boolean?,
)

data class LetterScore(
    /** 0..100, weighted for the mode. */
    val overall: Int,
    val shape: Int,
    val order: Int?,
    val direction: Int?,
    val start: Int?,
    val smoothness: Int?,
    val size: Int?,
    val baseline: Int?,
    val strokes: List<StrokeFeedback>,
    /** Most important first. */
    val issues: List<Issue>,
) {
    /** The single most useful tip, or null if the letter is good. */
    val tip: String? get() = issues.firstOrNull()?.message
}

/**
 * Distances in line units (x-height = 0.5). Starting values to be tuned with
 * real handwriting samples; finger input gets looser limits than a stylus.
 */
data class Tolerances(
    val shape: Double,
    val start: Double,
    val jitter: Double,
    val sizeLog: Double,
    val baseline: Double,
) {
    companion object {
        fun of(mode: Mode, input: InputKind): Tolerances {
            val shape = when (mode) {
                Mode.LEARN -> 0.12
                Mode.PRACTICE -> 0.15
                Mode.TEST -> 0.18
            }
            val f = if (input == InputKind.FINGER) 1.5 else 1.0
            return Tolerances(
                shape = shape * f,
                start = 0.12 * f,
                jitter = 0.012 * f,
                sizeLog = 0.45,
                baseline = 0.2 * f,
            )
        }
    }
}

/** How much each part counts towards the overall score, per mode. */
internal object Weights {
    fun of(mode: Mode): Map<String, Double> = when (mode) {
        Mode.LEARN -> mapOf("shape" to 0.6, "direction" to 0.2, "start" to 0.2)
        Mode.PRACTICE -> mapOf(
            "shape" to 0.4, "order" to 0.15, "direction" to 0.15, "start" to 0.1,
            "smoothness" to 0.1, "size" to 0.05, "baseline" to 0.05,
        )
        Mode.TEST -> mapOf(
            "shape" to 0.4, "order" to 0.05, "direction" to 0.1,
            "smoothness" to 0.1, "size" to 0.15, "baseline" to 0.2,
        )
    }
}
