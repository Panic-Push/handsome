package app.penwise.core.model

import kotlinx.serialization.json.Json

/** Reads and writes handwriting samples as JSON (used to collect test samples). */
object InkCodec {
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    fun decode(text: String): Ink = json.decodeFromString(Ink.serializer(), text)

    fun encode(ink: Ink): String = json.encodeToString(Ink.serializer(), ink)
}
