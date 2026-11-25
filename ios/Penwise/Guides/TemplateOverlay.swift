import SwiftUI

/// Draws a letter template as a dotted path with numbered green start dots
/// and an orange arrow showing which way each stroke goes. Strokes listed in
/// `highlight` are drawn solid red so a mistake is easy to see.
struct TemplateOverlay: View {
    let template: LetterTemplate
    let layout: GuideLayout
    var showPath = true
    var showArrows = true
    var showDots = true
    var pathOpacity: Double = 0.55
    var highlight: Set<Int> = []

    var body: some View {
        Canvas { context, _ in
            let unit = layout.unit
            for (index, stroke) in template.strokes.enumerated() {
                let points = stroke.cgPoints.map { layout.toScreen($0) }
                guard let first = points.first else { continue }
                let isProblem = highlight.contains(index)

                // The path: dotted grey, or solid red when it needs work.
                if showPath || isProblem {
                    var path = Path()
                    path.addLines(points)
                    if isProblem {
                        context.stroke(
                            path,
                            with: .color(Color.red.opacity(0.7)),
                            style: StrokeStyle(lineWidth: max(5, unit * 0.04), lineCap: .round, lineJoin: .round)
                        )
                    } else {
                        context.stroke(
                            path,
                            with: .color(Color.gray.opacity(pathOpacity)),
                            style: StrokeStyle(
                                lineWidth: max(4, unit * 0.035),
                                lineCap: .round,
                                lineJoin: .round,
                                dash: [0.1, max(8, unit * 0.05)]
                            )
                        )
                    }
                }

                // Direction arrow half-way along the stroke.
                if showArrows || isProblem,
                   PathMath.length(points) > unit * 0.1,
                   let pd = PathMath.pointAndDirection(points, at: 0.5) {
                    let s = max(10, unit * 0.06)
                    let d = pd.direction
                    let n = CGPoint(x: -d.y, y: d.x)
                    let m = pd.point
                    var arrow = Path()
                    arrow.move(to: CGPoint(x: m.x + d.x * s, y: m.y + d.y * s))
                    arrow.addLine(to: CGPoint(x: m.x - d.x * s * 0.6 + n.x * s * 0.7, y: m.y - d.y * s * 0.6 + n.y * s * 0.7))
                    arrow.addLine(to: CGPoint(x: m.x - d.x * s * 0.6 - n.x * s * 0.7, y: m.y - d.y * s * 0.6 - n.y * s * 0.7))
                    arrow.closeSubpath()
                    context.fill(arrow, with: .color(.orange))
                }

                // Numbered start dot.
                if showDots || isProblem {
                    let r = max(9, unit * 0.045)
                    let dot = Path(ellipseIn: CGRect(x: first.x - r, y: first.y - r, width: 2 * r, height: 2 * r))
                    context.fill(dot, with: .color(.green))
                    context.draw(
                        Text("\(index + 1)")
                            .font(.system(size: r * 1.2, weight: .bold, design: .rounded))
                            .foregroundColor(.white),
                        at: first
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}
