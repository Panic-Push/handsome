import SwiftUI

struct HomeView: View {
    @ObservedObject private var progress = ProgressStore.shared
    private let library = TemplateLibrary.shared

    private var templateIDs: [String] { library.templates.map(\.id) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    modeCards
                    if let last = progress.lastPlayed, let template = library.template(id: last.templateID) {
                        continueCard(mode: last.mode, template: template)
                    }
                    lettersOverview
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .safeAreaInset(edge: .bottom, spacing: 0) {
                AdBannerSlot()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: Route.recorder) {
                        Label("Recorder (developer)", systemImage: "wrench.and.screwdriver")
                    }
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .letters(let mode):
                    LetterPickerView(mode: mode)
                case .write(let mode, let templateID):
                    WritingView(mode: mode, templateID: templateID)
                case .recorder:
                    RecorderView()
                }
            }
        }
    }

    // MARK: - Header

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(greeting)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text("Let's make your handwriting beautiful today.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            StatPill(symbol: "flame.fill", color: .orange, value: "\(progress.streak)",
                     label: progress.streak == 1 ? "day streak" : "days streak")
            StatPill(symbol: "pencil.line", color: .blue, value: "\(progress.attemptsToday)",
                     label: "letters today")
        }
    }

    // MARK: - Mode cards

    private var modeCards: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Choose a mode")
                .font(.title2.weight(.bold))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 20)], spacing: 20) {
                ForEach(WritingMode.allCases) { mode in
                    NavigationLink(value: Route.letters(mode)) {
                        ModeCard(
                            mode: mode,
                            passed: progress.passedCount(mode, templateIDs: templateIDs),
                            total: templateIDs.count
                        )
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    // MARK: - Continue

    private func continueCard(mode: WritingMode, template: LetterTemplate) -> some View {
        NavigationLink(value: Route.write(mode, template.id)) {
            HStack(spacing: 18) {
                Text(template.glyph)
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .foregroundStyle(mode.color)
                    .frame(width: 72, height: 72)
                    .background(mode.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Continue where you left off")
                        .font(.headline)
                        .foregroundStyle(Color.primary)
                    Text("\(mode.rawValue) · letter \(template.glyph) · best \(progress.best(mode, template.id) ?? 0)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(mode.color)
            }
            .padding(18)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: - Letters overview

    private var lettersOverview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Your letters")
                    .font(.title2.weight(.bold))
                Spacer()
                HStack(spacing: 14) {
                    ForEach(WritingMode.allCases) { mode in
                        HStack(spacing: 5) {
                            Circle().fill(mode.color).frame(width: 9, height: 9)
                            Text(mode.rawValue)
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(library.templates) { template in
                        NavigationLink(value: Route.write(suggestedMode(for: template), template.id)) {
                            VStack(spacing: 8) {
                                Text(template.glyph)
                                    .font(.system(size: 40, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.primary)
                                HStack(spacing: 5) {
                                    ForEach(WritingMode.allCases) { mode in
                                        Circle()
                                            .fill(isPassed(mode, template) ? mode.color : Color.secondary.opacity(0.25))
                                            .frame(width: 9, height: 9)
                                    }
                                }
                            }
                            .frame(width: 84, height: 100)
                            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func isPassed(_ mode: WritingMode, _ template: LetterTemplate) -> Bool {
        (progress.best(mode, template.id) ?? 0) >= ProgressStore.passMark
    }

    /// The first mode this letter has not passed yet.
    private func suggestedMode(for template: LetterTemplate) -> WritingMode {
        WritingMode.allCases.first { !isPassed($0, template) } ?? .test
    }
}

private struct StatPill: View {
    let symbol: String
    let color: Color
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.title2.weight(.bold).monospacedDigit())
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ModeCard: View {
    let mode: WritingMode
    let passed: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                Image(systemName: mode.symbol)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(Color.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Spacer()
                ProgressRing(
                    fraction: total == 0 ? 0 : Double(passed) / Double(total),
                    label: "\(passed)/\(total)"
                )
            }
            Text(mode.rawValue)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(mode.subtitle)
                .font(.callout)
                .foregroundStyle(Color.white.opacity(0.92))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                Text(mode.callToAction)
                Image(systemName: "arrow.right")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.2), in: Capsule())
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 280, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [mode.color, mode.color.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .shadow(color: mode.color.opacity(0.3), radius: 14, y: 8)
    }
}
