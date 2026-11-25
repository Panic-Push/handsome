package app.penwise.core.geometry

import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sqrt

data class Vec(val x: Double, val y: Double) {
    operator fun plus(o: Vec) = Vec(x + o.x, y + o.y)
    operator fun minus(o: Vec) = Vec(x - o.x, y - o.y)
    operator fun times(s: Double) = Vec(x * s, y * s)
    fun dot(o: Vec) = x * o.x + y * o.y
    fun length() = sqrt(x * x + y * y)
    fun distanceTo(o: Vec) = hypot(x - o.x, y - o.y)
}

data class Bounds(val minX: Double, val minY: Double, val maxX: Double, val maxY: Double) {
    val width get() = maxX - minX
    val height get() = maxY - minY
    val center get() = Vec((minX + maxX) / 2, (minY + maxY) / 2)
    val diagonal get() = hypot(width, height)
}

/** Pure geometry helpers used by the scoring engine. */
object Geometry {

    fun pathLength(p: List<Vec>): Double {
        var total = 0.0
        for (i in 1 until p.size) total += p[i - 1].distanceTo(p[i])
        return total
    }

    /** Returns exactly [n] points spaced evenly along the path. */
    fun resample(p: List<Vec>, n: Int): List<Vec> {
        require(n >= 2) { "n must be at least 2" }
        if (p.isEmpty()) return emptyList()
        val total = pathLength(p)
        if (p.size == 1 || total < 1e-9) return List(n) { p[0] }

        val step = total / (n - 1)
        val out = ArrayList<Vec>(n)
        out.add(p[0])
        var acc = 0.0
        var prev = p[0]
        var i = 1
        while (i < p.size && out.size < n - 1) {
            val cur = p[i]
            val d = prev.distanceTo(cur)
            if (d > 0 && acc + d >= step) {
                val q = prev + (cur - prev) * ((step - acc) / d)
                out.add(q)
                prev = q
                acc = 0.0
            } else {
                acc += d
                prev = cur
                i++
            }
        }
        while (out.size < n) out.add(p.last())
        return out
    }

    /** Resamples so neighbouring points are about [spacing] apart. */
    fun resampleBySpacing(p: List<Vec>, spacing: Double): List<Vec> {
        val n = max(2, (pathLength(p) / spacing).roundToInt() + 1)
        return resample(p, n)
    }

    /** Average distance from each point of [a] to its nearest point in [b]. */
    fun directedDistance(a: List<Vec>, b: List<Vec>): Double {
        if (a.isEmpty() || b.isEmpty()) return Double.MAX_VALUE
        var sum = 0.0
        for (p in a) {
            var best = Double.MAX_VALUE
            for (q in b) {
                val d = p.distanceTo(q)
                if (d < best) best = d
            }
            sum += best
        }
        return sum / a.size
    }

    /** Symmetric shape distance that ignores drawing direction and start point. */
    fun chamfer(a: List<Vec>, b: List<Vec>): Double =
        (directedDistance(a, b) + directedDistance(b, a)) / 2

    /**
     * Shape distance used for scoring: the worse of "ink away from the path"
     * and "path not covered by ink", so missing parts count fully.
     */
    fun shapeDistance(user: List<Vec>, template: List<Vec>): Double =
        max(directedDistance(user, template), directedDistance(template, user))

    fun bounds(points: List<Vec>): Bounds {
        var minX = Double.MAX_VALUE
        var minY = Double.MAX_VALUE
        var maxX = -Double.MAX_VALUE
        var maxY = -Double.MAX_VALUE
        for (p in points) {
            minX = min(minX, p.x); minY = min(minY, p.y)
            maxX = max(maxX, p.x); maxY = max(maxY, p.y)
        }
        return Bounds(minX, minY, maxX, maxY)
    }

    fun movingAverage(p: List<Vec>, half: Int): List<Vec> = p.indices.map { i ->
        val from = max(0, i - half)
        val to = min(p.size - 1, i + half)
        var sx = 0.0
        var sy = 0.0
        for (k in from..to) { sx += p[k].x; sy += p[k].y }
        val n = (to - from + 1).toDouble()
        Vec(sx / n, sy / n)
    }

    /**
     * How well the user's travel direction agrees with the template's, 0..1.
     * For every user segment we look at the nearest template segments and
     * compare tangents. Works for loops and for strokes started mid-way.
     * Where the template retraces itself (the stem of a cursive d goes up and
     * back down), nearby segments point both ways; those user segments are
     * ambiguous and are skipped.
     */
    fun directionAgreement(user: List<List<Vec>>, template: List<List<Vec>>): Double {
        val segments = ArrayList<Pair<Vec, Vec>>() // (start point, tangent)
        for (t in template) {
            for (m in 0 until t.size - 1) {
                val dt = t[m + 1] - t[m]
                if (dt.length() > 1e-9) segments += t[m] to dt
            }
        }
        if (segments.isEmpty()) return 1.0

        var aligned = 0.0
        var total = 0.0
        for (stroke in user) {
            for (k in 0 until stroke.size - 1) {
                val du = stroke[k + 1] - stroke[k]
                val len = du.length()
                if (len < 1e-9) continue
                val mid = (stroke[k] + stroke[k + 1]) * 0.5
                var best = Double.MAX_VALUE
                for ((p, dt) in segments) best = min(best, distanceToSegment(mid, p, dt))
                var agree = false
                var disagree = false
                for ((p, dt) in segments) {
                    if (distanceToSegment(mid, p, dt) > best + AMBIGUITY) continue
                    if (du.dot(dt) > 0) agree = true else disagree = true
                }
                if (agree && disagree) continue
                total += len
                if (agree) aligned += len
            }
        }
        return if (total == 0.0) 1.0 else aligned / total
    }

    /** Distance from [q] to the segment that starts at [p] and runs along [d]. */
    fun distanceToSegment(q: Vec, p: Vec, d: Vec): Double {
        val len2 = d.dot(d)
        if (len2 < 1e-12) return q.distanceTo(p)
        val t = ((q - p).dot(d) / len2).coerceIn(0.0, 1.0)
        return q.distanceTo(p + d * t)
    }

    /** Template segments this much further than the nearest still count as "nearby". */
    private const val AMBIGUITY = 0.02

    /** Root-mean-square distance of a path from a smoothed copy of itself. */
    fun jitter(p: List<Vec>): Double {
        if (p.size < 3) return 0.0
        val even = resampleBySpacing(p, 0.01)
        val smooth = movingAverage(even, 3)
        var sum = 0.0
        for (i in even.indices) {
            val d = even[i].distanceTo(smooth[i])
            sum += d * d
        }
        return sqrt(sum / even.size)
    }

    fun clamp01(v: Double) = if (v < 0) 0.0 else if (v > 1) 1.0 else v

    fun approxEquals(a: Double, b: Double, eps: Double = 1e-9) = abs(a - b) <= eps
}
