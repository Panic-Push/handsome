import SwiftUI

/// Between Home and a destination: names where the learner is going and holds
/// the second ad. "Continue" belongs to Penwise, sits below the ad and works as
/// soon as the destination is ready (it is local, so straight away). Back
/// returns to Home and cancels the entry.
struct EntryView: View {
    let target: EntryTarget
    @Binding var path: [Route]

    private var title: String {
        switch target {
        case .mode(let mode): return "\(AppSettings.shared.style.title) · \(mode.rawValue)"
        case .journeyMap(let id), .journeyResume(let id): return JourneyLibrary.shared.journey(id: id)?.title ?? "Journey"
        }
    }

    private var subtitle: String {
        switch target {
        case .mode(let mode): return mode.subtitle
        case .journeyMap: return "Your chapters and letters"
        case .journeyResume(let id):
            guard let journey = JourneyLibrary.shared.journey(id: id) else { return "" }
            return JourneyStore.shared.hasStarted(journey) ? "Pick up where you left off" : "Your chapters and letters"
        }
    }

    private var continueLabel: String {
        switch target {
        case .mode(let mode): return mode.callToAction
        case .journeyMap: return "Open chapter map"
        case .journeyResume(let id):
            guard let journey = JourneyLibrary.shared.journey(id: id) else { return "Continue" }
            let store = JourneyStore.shared
            guard store.hasStarted(journey) else { return "Open chapter map" }
            let p = store.position(in: journey)
            let letters = journey.chapter(p.chapterID).map { store.letters($0, in: journey) } ?? []
            let glyph = p.letterIndex < letters.count ? letters[p.letterIndex] : ""
            return "Continue with \(glyph)"
        }
    }

    private var symbol: String {
        if case .mode(let mode) = target { return mode.symbol }
        return "book.closed"
    }

    private var color: Color {
        if case .mode(let mode) = target { return mode.color }
        return WritingMode.learn.color
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 16)
            VStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(color, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                Text(title)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)
                Text(subtitle)
                    .font(.workbook(.title3, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .padding(22)
            .frame(maxWidth: 520)
            .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 24))
            AdSlot(placement: .modeEntry)
            Button(action: proceed) {
                Text(continueLabel)
                    .font(.headline)
                    .frame(minWidth: 280)
            }
            .buttonStyle(.borderedProminent)
            .tint(color)
            .controlSize(.large)
            Spacer(minLength: 16)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.paper)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Replaces this screen with the destination, so Back returns to Home.
    private func proceed() {
        let destination = target.destination
        if !path.isEmpty { path.removeLast() }
        path.append(destination)
    }
}
