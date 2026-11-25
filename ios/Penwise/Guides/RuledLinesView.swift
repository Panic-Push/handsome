import SwiftUI

/// The four writing lines: ascender, x-height (dashed), baseline (strong),
/// descender. Lines listed in `highlighted` (in line units) are drawn in red
/// to point at a correction, e.g. the baseline.
struct RuledLinesView: View {
    let layout: GuideLayout
    var highlighted: [CGFloat] = []

    private struct Rule {
        let units: CGFloat
        let opacity: Double
        let width: CGFloat
        let dash: [CGFloat]
    }

    private let rules: [Rule] = [
        Rule(units: 0.0, opacity: 0.45, width: 1, dash: []),
        Rule(units: 0.5, opacity: 0.55, width: 1, dash: [8, 6]),
        Rule(units: 1.0, opacity: 0.9, width: 2, dash: []),
        Rule(units: 1.5, opacity: 0.45, width: 1, dash: []),
    ]

    var body: some View {
        Canvas { context, size in
            for rule in rules {
                let y = layout.y(rule.units)
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                let isHighlighted = highlighted.contains(rule.units)
                context.stroke(
                    path,
                    with: .color(isHighlighted ? Color.red.opacity(0.8) : Color.rule.opacity(rule.opacity)),
                    style: StrokeStyle(lineWidth: isHighlighted ? 3.5 : rule.width, dash: isHighlighted ? [] : rule.dash)
                )
            }
        }
        .allowsHitTesting(false)
    }
}
