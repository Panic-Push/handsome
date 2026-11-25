package app.penwise.core

import app.penwise.core.model.Ink
import app.penwise.core.model.InkPoint
import app.penwise.core.model.InkStroke
import app.penwise.core.scoring.LetterScorer
import app.penwise.core.scoring.Mode
import app.penwise.core.template.TemplateCodec
import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/** Checks every template shipped in /content loads and scores itself perfectly. */
class ContentTemplatesTest {
    private val dir = File("../content/templates")

    /** a -> 0061.json (code points, so "a" and "A" never collide on macOS). */
    private fun fileNameFor(glyph: String) =
        glyph.codePoints().toArray().joinToString("_") { "%04X".format(it) } + ".json"

    @Test
    fun allTemplatesLoadAndSelfScorePerfectly() {
        val files = dir.walkTopDown().filter { it.extension == "json" }.toList()
        assertTrue(files.isNotEmpty(), "no templates found in ${dir.absolutePath}")
        val ids = mutableSetOf<String>()
        for (f in files) {
            val t = TemplateCodec.decode(f.readText())
            assertTrue(ids.add(t.id), "duplicate id ${t.id}")
            assertEquals(fileNameFor(t.glyph), f.name, "file name should be the glyph's code points")
            assertTrue(t.strokes.all { it.points.size >= 2 && it.points.all { p -> p.size == 2 } }, "bad points in $f")
            val ink = Ink(t.strokes.map { s -> InkStroke(s.points.map { InkPoint(it[0], it[1]) }) })
            for (mode in Mode.entries) {
                val score = LetterScorer().score(ink, t, mode)
                assertTrue(score.overall >= 95, "${t.id} $mode scored ${score.overall}: ${score.issues}")
            }
        }
    }

    @Test
    fun templatesRoundTripThroughJson() {
        val f = File(dir, "latin/print-modern/${fileNameFor("a")}")
        val t = TemplateCodec.decode(f.readText())
        assertEquals(t, TemplateCodec.decode(TemplateCodec.encode(t)))
        assertEquals(1, t.alternates.size)
    }
}
