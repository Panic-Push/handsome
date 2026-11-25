import SwiftUI

/// A short burst of confetti, used for great scores.
struct ConfettiView: View {
    let start: Date

    private static let colors: [Color] = [.pink, .orange, .yellow, .green, .blue, .purple]
    private static let pieces = 90

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = CGFloat(timeline.date.timeIntervalSince(start))
            Canvas { context, size in
                for i in 0..<ConfettiView.pieces {
                    let seed = CGFloat(i + 1)
                    let r1 = ConfettiView.random(seed * 12.9898)
                    let r2 = ConfettiView.random(seed * 78.233)
                    let r3 = ConfettiView.random(seed * 39.425)

                    let x0 = size.width * (0.5 + (r1 - 0.5) * 0.3)
                    let vx = (r2 - 0.5) * size.width * 0.9
                    let vy = -size.height * (0.7 + r3 * 0.6)
                    let gravity = size.height * 1.8
                    let x = x0 + vx * t
                    let y = size.height * 0.85 + vy * t + 0.5 * gravity * t * t

                    var piece = context
                    piece.translateBy(x: x, y: y)
                    piece.rotate(by: .radians(Double(t * (4 + r1 * 8))))
                    piece.opacity = Double(max(0, 1 - t / 2.2))
                    piece.fill(
                        Path(CGRect(x: -6, y: -3.5, width: 12, height: 7)),
                        with: .color(ConfettiView.colors[i % ConfettiView.colors.count])
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// Repeatable pseudo-random number in 0..<1 for a seed.
    private static func random(_ v: CGFloat) -> CGFloat {
        let x = sin(v) * 43758.5453
        return x - floor(x)
    }
}
