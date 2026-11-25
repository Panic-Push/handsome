import SwiftUI

/// Between Home and a mode's letters: names the mode and holds the second ad.
/// "Continue" sits outside the ad and works straight away.
struct ModeEntryView: View {
    let mode: WritingMode
    @Binding var path: [Route]

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 16)
            VStack(spacing: 10) {
                Image(systemName: mode.symbol)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(mode.color, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                Text(mode.rawValue)
                    .font(.system(size: 40, weight: .bold, design: .serif))
                    .foregroundStyle(Color.ink)
                Text(mode.subtitle)
                    .font(.workbook(.title3, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            AdSlot(placement: .modeEntry)
            Button(action: proceed) {
                Text(mode.callToAction)
                    .font(.headline)
                    .frame(minWidth: 280)
            }
            .buttonStyle(.borderedProminent)
            .tint(mode.color)
            .controlSize(.large)
            Spacer(minLength: 16)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.paper)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Replaces this screen with the letters, so Back returns to Home.
    private func proceed() {
        if !path.isEmpty { path.removeLast() }
        path.append(.letters(mode))
    }
}
