package app.penwise.core.model

import kotlinx.serialization.Serializable

/**
 * Coordinates everywhere in the core are in "line units", measured against the
 * ruled writing lines (y grows downward, like the screen):
 *
 *   y = 0.0  ascender line   (top of l, d, t)
 *   y = 0.5  x-height line   (top of a, c, o)
 *   y = 1.0  baseline        (letters sit here)
 *   y = 1.5  descender line  (bottom of g, p, y)
 *
 * The app converts screen points to line units before scoring, so the engine
 * never depends on screen size.
 */
object Guides {
    const val ASCENDER = 0.0
    const val X_HEIGHT = 0.5
    const val BASELINE = 1.0
    const val DESCENDER = 1.5
}

/** One sampled pen position. */
@Serializable
data class InkPoint(
    val x: Double,
    val y: Double,
    /** Seconds since the stroke began. */
    val t: Double = 0.0,
    /** Normalised pressure 0..1, or -1 when unknown (finger input). */
    val force: Double = -1.0,
)

/** Everything drawn between pen-down and pen-up. */
@Serializable
data class InkStroke(val points: List<InkPoint>)

@Serializable
enum class InputKind { STYLUS, FINGER }

/** One attempt at writing something: a letter, word or sentence. */
@Serializable
data class Ink(
    val strokes: List<InkStroke>,
    val input: InputKind = InputKind.STYLUS,
)
