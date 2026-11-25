package app.penwise.core

import app.penwise.core.geometry.Geometry
import app.penwise.core.geometry.Vec
import app.penwise.core.model.InputKind
import app.penwise.core.model.Ink
import app.penwise.core.model.InkPoint
import app.penwise.core.model.InkStroke
import app.penwise.core.template.LetterTemplate
import app.penwise.core.template.TemplateStroke
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

/** Helpers that fake handwriting for tests. */
object TestInk {

    fun arc(cx: Double, cy: Double, rx: Double, ry: Double, startDeg: Double, endDeg: Double, n: Int = 28): List<Vec> =
        (0 until n).map { i ->
            val a = (startDeg + (endDeg - startDeg) * i / (n - 1)) * kotlin.math.PI / 180
            Vec(cx + rx * cos(a), cy - ry * sin(a))
        }

    fun line(x1: Double, y1: Double, x2: Double, y2: Double) = listOf(Vec(x1, y1), Vec(x2, y2))

    fun template(glyph: String, vararg strokes: List<Vec>, alternates: List<List<List<Vec>>> = emptyList()) =
        LetterTemplate(
            id = "test.$glyph", glyph = glyph, script = "latin", style = "test", width = 0.5,
            strokes = strokes.map { s -> TemplateStroke(s.map { listOf(it.x, it.y) }) },
            alternates = alternates.map { form -> form.map { s -> TemplateStroke(s.map { listOf(it.x, it.y) }) } },
        )

    val c = template("c", arc(0.25, 0.75, 0.22, 0.25, 40.0, 320.0))
    val o = template("o", arc(0.26, 0.75, 0.22, 0.25, 70.0, 430.0, 36))
    val t = template("t", line(0.15, 0.15, 0.15, 1.0), line(0.0, 0.5, 0.32, 0.5))
    private val bowl = arc(0.24, 0.75, 0.2, 0.25, 20.0, 380.0, 36)
    val a = template(
        "a", bowl, line(0.44, 0.5, 0.44, 1.0),
        alternates = listOf(listOf(bowl + line(0.44, 0.5, 0.44, 1.0))),
    )
    val i = template("i", line(0.1, 0.5, 0.1, 1.0), line(0.1, 0.3, 0.1, 0.31))

    /** Writes the template perfectly, densely sampled like a real pen. */
    fun perfect(template: LetterTemplate) = ink(template.strokes.map { it.toVecs() })

    fun ink(strokes: List<List<Vec>>, input: InputKind = InputKind.STYLUS) = Ink(
        strokes = strokes.map { s ->
            val dense = Geometry.resample(s, 60)
            InkStroke(dense.mapIndexed { k, p -> InkPoint(p.x, p.y, k * 0.008, 0.5) })
        },
        input = input,
    )

    fun strokesOf(template: LetterTemplate) = template.strokes.map { it.toVecs() }

    fun transform(strokes: List<List<Vec>>, f: (Vec) -> Vec) = strokes.map { s -> s.map(f) }

    /** Adds wobble to every point (a shaky hand). */
    fun shaky(strokes: List<List<Vec>>, amount: Double, seed: Int = 7): List<List<Vec>> {
        val r = Random(seed)
        return strokes.map { s ->
            Geometry.resample(s, 120).map { Vec(it.x + (r.nextDouble() - 0.5) * 2 * amount, it.y + (r.nextDouble() - 0.5) * 2 * amount) }
        }
    }
}
