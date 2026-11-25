import SwiftUI

/// The four writing lines: ascender, x-height (dashed), baseline (strong), descender.
struct RuledLinesView: View {
    let layout: GuideLayout

    private struct Rule {
        let units: CGFloat
        let color: Color
        let width: CGFloat
        let dash: [CGFloat]
    }

    private let rules: [Rule] = [
        Rule(units: 0.0, color: Color.secondary.opacity(0.35), width: 1, dash: []),
        Rule(units: 0.5, color: Color.blue.opacity(0.45), width: 1, dash: [8, 6]),
        Rule(units: 1.0, color: Color.primary.opacity(0.6), width: 2, dash: []),
        Rule(units: 1.5, color: Color.secondary.opacity(0.35), width: 1, dash: []),
    ]

    var body: some View {
        Canvas { context, size in
            for rule in rules {
                let y = layout.y(rule.units)
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(
                    path,
                    with: .color(rule.color),
                    style: StrokeStyle(lineWidth: rule.width, dash: rule.dash)
                )
            }
        }
        .allowsHitTesting(false)
    }
}
