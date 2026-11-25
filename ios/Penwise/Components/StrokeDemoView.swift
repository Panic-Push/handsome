import SwiftUI

/// Animates a letter being written, stroke by stroke, with a pen dot at the tip.
struct StrokeDemoView: View {
    let template: LetterTemplate
    let layout: GuideLayout
    let start: Date
    var color: Color = .blue

    /// Writing speed in line units per second.
    static let speed: CGFloat = 0.9
    /// Pause between strokes, in seconds.
    static let pause: Double = 0.35

    static func strokeDuration(_ stroke: TemplateStroke) -> Double {
        max(0.25, Double(PathMath.length(stroke.cgPoints) / speed))
    }

    /// Total length of the animation, in seconds.
    static func duration(for template: LetterTemplate) -> Double {
        template.strokes.reduce(0) { $0 + strokeDuration($1) + pause }
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(start)
            Canvas { context, _ in
                var remaining = elapsed
                let width = max(5, layout.unit * 0.04)
                for stroke in template.strokes {
                    if remaining <= 0 { break }
                    let points = stroke.cgPoints.map { layout.toScreen($0) }
                    let d = StrokeDemoView.strokeDuration(stroke)
                    let fraction = min(1, remaining / d)
                    let shown = PathMath.prefix(points, fraction: CGFloat(fraction))

                    var path = Path()
                    path.addLines(shown)
                    context.stroke(
                        path,
                        with: .color(color),
                        style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
                    )
                    if fraction < 1, let tip = shown.last {
                        let r = width * 1.6
                        context.fill(
                            Path(ellipseIn: CGRect(x: tip.x - r, y: tip.y - r, width: 2 * r, height: 2 * r)),
                            with: .color(color.opacity(0.35))
                        )
                    }
                    remaining -= d + StrokeDemoView.pause
                }
            }
        }
        .allowsHitTesting(false)
    }
}
