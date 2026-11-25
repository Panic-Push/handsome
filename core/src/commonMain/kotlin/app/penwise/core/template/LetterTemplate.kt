package app.penwise.core.template

import app.penwise.core.geometry.Vec
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * The correct way to write one letter: its strokes in order, each stroke a
 * polyline in line units (see [app.penwise.core.model.Guides]).
 */
@Serializable
data class LetterTemplate(
    /** Unique id, e.g. "latin.print-modern.c". */
    val id: String,
    /** The character(s) this template draws. A grapheme cluster, so it also fits Hindi and Malayalam. */
    val glyph: String,
    val script: String,
    val style: String,
    /** Horizontal space the letter takes, in line units. */
    val width: Double,
    /** Strokes in the order they should be written. */
    val strokes: List<TemplateStroke>,
    /** Other accepted ways to write the same letter (e.g. a one-stroke "a"). */
    val alternates: List<List<TemplateStroke>> = emptyList(),
)

@Serializable
data class TemplateStroke(
    /** Points as [x, y] pairs, in drawing order. */
    val points: List<List<Double>>,
) {
    fun toVecs(): List<Vec> = points.map { Vec(it[0], it[1]) }
}

object TemplateCodec {
    private val json = Json {
        ignoreUnknownKeys = true
        prettyPrint = true
        encodeDefaults = false
    }

    /** Throws (a Swift error on iOS) if the JSON is not a valid template. */
    @Throws(Exception::class)
    fun decode(text: String): LetterTemplate = json.decodeFromString(LetterTemplate.serializer(), text)

    fun encode(template: LetterTemplate): String = json.encodeToString(LetterTemplate.serializer(), template)
}
