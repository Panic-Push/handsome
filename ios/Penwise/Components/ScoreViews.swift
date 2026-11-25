import SwiftUI

/// Colour for a 0-100 score.
func scoreColor(_ score: Int) -> Color {
    if score >= 85 { return .green }
    if score >= 60 { return .orange }
    return .red
}

/// A ring that fills up to the score when it appears.
struct ScoreRing: View {
    let score: Int
    var size: CGFloat = 86

    @State private var shown: CGFloat = 0

    var body: some View {
        ZStack {
            Circle().stroke(scoreColor(score).opacity(0.18), lineWidth: 9)
            Circle()
                .trim(from: 0, to: shown)
                .stroke(scoreColor(score), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(score)")
                .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
        }
        .frame(width: size, height: size)
        .onAppear {
            shown = 0
            withAnimation(.easeOut(duration: 0.9)) { shown = CGFloat(score) / 100 }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score \(score) out of 100")
    }
}

/// Up to three stars; optionally pop in one after another.
struct StarsView: View {
    let count: Int
    var size: CGFloat = 18
    var spacing: CGFloat = 3
    var animated = false

    @State private var appeared = false

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: i < count ? "star.fill" : "star")
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(i < count ? Color.yellow : Color.secondary.opacity(0.4))
                    .scaleEffect(!animated || appeared ? 1 : 0.2)
                    .opacity(!animated || appeared ? 1 : 0)
                    .animation(
                        animated ? .spring(response: 0.4, dampingFraction: 0.5).delay(0.5 + 0.15 * Double(i)) : nil,
                        value: appeared
                    )
            }
        }
        .onAppear { appeared = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) of 3 stars")
    }
}

/// A small progress ring with a label in the middle.
struct ProgressRing: View {
    let fraction: Double
    let label: String
    var color: Color = .white
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.25), lineWidth: 6)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(fraction, 0), 1)))
                .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(label)
                .font(.system(size: size * 0.24, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
    }
}

struct PartChip: View {
    let part: ScorePart

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(scoreColor(part.value)).frame(width: 8, height: 8)
            Text("\(part.name) \(part.value)")
        }
        .font(.callout.monospacedDigit())
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.secondary.opacity(0.12), in: Capsule())
    }
}

/// A letter with its stars and best score, used in grids.
struct LetterTile: View {
    let template: LetterTemplate
    let best: Int?
    let color: Color

    private var passed: Bool { (best ?? 0) >= ProgressStore.passMark }

    var body: some View {
        VStack(spacing: 10) {
            LetterThumbnail(template: template, lineWidth: 4)
                .frame(width: 80, height: 84)
            StarsView(count: ProgressStore.stars(for: best), size: 16)
            Text(best.map { "Best \($0)" } ?? "New")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.paperCard, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(passed ? color : Color.cardBorder, lineWidth: passed ? 2.5 : 1)
        )
        .overlay(alignment: .topTrailing) {
            if passed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(color)
                    .font(.title3)
                    .padding(10)
            }
        }
    }
}
