package app.penwise.core

import app.penwise.core.template.TemplateCodec
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.io.File
import kotlin.test.Test
import kotlin.test.assertTrue

/** Every letter a journey uses must have a template in the journey's style. */
class JourneyContentTest {
    private val content = File("../content")

    @Test
    fun journeysOnlyUseExistingLetters() {
        val glyphsByStyle = File(content, "templates").walkTopDown()
            .filter { it.extension == "json" }
            .map { TemplateCodec.decode(it.readText()) }
            .groupBy({ it.style }, { it.glyph })

        val journeys = File(content, "journeys").listFiles { f -> f.extension == "json" }.orEmpty()
        assertTrue(journeys.isNotEmpty(), "no journeys found")
        for (file in journeys) {
            val j = Json.parseToJsonElement(file.readText()).jsonObject
            val style = j["style"]!!.jsonPrimitive.content
            val available = glyphsByStyle[style].orEmpty()
            val chapters = j["chapters"]!!.jsonArray
            assertTrue(chapters.isNotEmpty(), "${file.name}: no chapters")
            for (c in chapters) {
                val chapter = c.jsonObject
                val letters = chapter["letters"]!!.jsonArray.map { it.jsonPrimitive.content }
                assertTrue(letters.isNotEmpty(), "${file.name}: empty chapter")
                for (g in letters) assertTrue(g in available, "${file.name}: no $style template for '$g'")
                if (chapter["checkpoint"]?.jsonPrimitive?.boolean == true) {
                    val pick = chapter["pick"]!!.jsonPrimitive.int
                    assertTrue(pick in 1..letters.size, "${file.name}: bad pick $pick")
                }
            }
        }
    }
}
