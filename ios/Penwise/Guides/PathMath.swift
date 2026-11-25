import CoreGraphics

/// Small path helpers for drawing guides and simplifying recorded strokes.
enum PathMath {
    struct PointAndDirection {
        let point: CGPoint
        /// Unit vector of travel at that point.
        let direction: CGPoint
    }

    static func length(_ p: [CGPoint]) -> CGFloat {
        guard p.count >= 2 else { return 0 }
        var total: CGFloat = 0
        for i in 1..<p.count {
            total += hypot(p[i].x - p[i - 1].x, p[i].y - p[i - 1].y)
        }
        return total
    }

    /// The point a given fraction (0...1) of the way along the path.
    static func pointAndDirection(_ p: [CGPoint], at fraction: CGFloat) -> PointAndDirection? {
        guard p.count >= 2 else { return nil }
        let target = length(p) * fraction
        var acc: CGFloat = 0
        for i in 1..<p.count {
            let a = p[i - 1]
            let b = p[i]
            let d = hypot(b.x - a.x, b.y - a.y)
            if d > 0 && acc + d >= target {
                let t = (target - acc) / d
                let point = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
                let direction = CGPoint(x: (b.x - a.x) / d, y: (b.y - a.y) / d)
                return PointAndDirection(point: point, direction: direction)
            }
            acc += d
        }
        return nil
    }

    /// The first `fraction` (0...1) of the path, ending exactly at that point.
    static func prefix(_ p: [CGPoint], fraction: CGFloat) -> [CGPoint] {
        guard p.count >= 2 else { return p }
        if fraction >= 1 { return p }
        let target = length(p) * max(0, fraction)
        var out = [p[0]]
        var acc: CGFloat = 0
        for i in 1..<p.count {
            let a = p[i - 1]
            let b = p[i]
            let d = hypot(b.x - a.x, b.y - a.y)
            if acc + d >= target {
                let t = d > 0 ? (target - acc) / d : 0
                out.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
                return out
            }
            out.append(b)
            acc += d
        }
        return out
    }

    /// Evenly spaced points about `spacing` apart along the path.
    static func resample(_ p: [CGPoint], spacing: CGFloat) -> [CGPoint] {
        guard p.count >= 2, let last = p.last else { return p }
        let n = max(2, Int((length(p) / spacing).rounded()) + 1)
        var out: [CGPoint] = []
        out.reserveCapacity(n)
        for k in 0..<n {
            let f = CGFloat(k) / CGFloat(n - 1)
            if let pd = pointAndDirection(p, at: f) {
                out.append(pd.point)
            } else {
                out.append(last)
            }
        }
        return out
    }
}
