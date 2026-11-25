import SwiftUI

/// What changed between two tries, in one sentence.
struct Comparison {
    let text: String
    let improved: Bool

    /// Compares a retry with the try before it, focusing on what the earlier
    /// tip asked for.
    static func make(previous: ScoreResult, current: ScoreResult, glyph: String) -> Comparison? {
        guard let kind = previous.primaryKind else {
            if current.overall > previous.overall + 3 {
                return Comparison(text: "Your new \(glyph) scores even higher.", improved: true)
            }
            return nil
        }
        let (part, phrase) = focus(for: kind)
        let fixed = !current.issueKinds.contains(kind)
        let before = previous.part(part) ?? previous.overall
        let after = current.part(part) ?? current.overall
        if fixed {
            return Comparison(text: "Your new \(glyph) \(phrase).", improved: true)
        }
        if after > before + 3 {
            return Comparison(text: "Getting closer: your new \(glyph) \(phrase), but not quite yet.", improved: true)
        }
        return Comparison(text: "About the same as last time. Compare it with the dotted grey try.", improved: false)
    }

    /// The score part and the words for fixing each kind of issue.
    private static func focus(for kind: String) -> (String, String) {
        switch kind {
        case "OFF_BASELINE": return ("Baseline", "sits on the baseline")
        case "TOO_BIG", "TOO_SMALL": return ("Size", "is the right size")
        case "STROKE_DIRECTION": return ("Direction", "goes the right way")
        case "START_POINT": return ("Start", "starts at the green dot")
        case "STROKE_ORDER": return ("Order", "has its strokes in the right order")
        case "STROKE_COUNT": return ("Order", "uses the right number of strokes")
        case "SHAKY": return ("Smoothness", "has a smoother line")
        default: return ("Shape", "follows the shape closely")
        }
    }
}

/// Score, stars, part scores and recent tries, shown under "Details".
struct ScoreDetailsView: View {
    let result: ScoreResult
    let history: [ProgressStore.Attempt]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                ScoreRing(score: result.overall, size: 72)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Score details")
                        .font(.workbook(.headline))
                    StarsView(count: ProgressStore.stars(for: result.overall), size: 18)
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), alignment: .leading)], alignment: .leading, spacing: 8) {
                ForEach(result.parts) { PartChip(part: $0) }
            }
            if !history.isEmpty {
                Divider()
                Text("Recent tries")
                    .font(.subheadline.weight(.semibold))
                ForEach(Array(history.enumerated()), id: \.offset) { _, attempt in
                    HStack(spacing: 10) {
                        Text("\(attempt.score)")
                            .font(.body.weight(.bold).monospacedDigit())
                            .frame(width: 36, alignment: .leading)
                        Text(attempt.date, style: .time)
                            .foregroundStyle(.secondary)
                        if attempt.hinted {
                            Text("With hint")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2), in: Capsule())
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
