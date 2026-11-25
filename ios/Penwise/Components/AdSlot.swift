import SwiftUI

/// A clearly labelled space for an ad. Real ads (Google AdMob) and the
/// "Remove ads" purchase come in Phase 2; until then this shows a placeholder
/// of the final size, so layouts don't move when ads arrive.
struct AdSlot: View {
    enum Placement {
        /// Shallow banner under the Home mode cards.
        case home
        /// Larger box on the screen between Home and a mode.
        case modeEntry

        var size: CGSize {
            switch self {
            case .home: return CGSize(width: 728, height: 90)
            case .modeEntry: return CGSize(width: 336, height: 280)
            }
        }
    }

    let placement: Placement

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ADVERTISEMENT")
                .font(.caption2.weight(.semibold))
                .tracking(1)
                .foregroundStyle(.secondary)
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.07))
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
                Text("Ad preview")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: placement.size.width)
            .frame(height: placement.size.height)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Advertisement placeholder")
    }
}
