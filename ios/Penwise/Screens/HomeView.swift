import SwiftUI

struct HomeView: View {
    @ObservedObject private var progress = ProgressStore.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var path: [Route] = []
    @State private var showSettings = false

    private let library = TemplateLibrary.shared

    private var letters: [LetterTemplate] { library.templates(style: settings.style) }
    private var letterIDs: [String] { letters.map(\.id) }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    primaryAction
                    modes
                    if settings.showAdPlaceholders {
                        AdSlot(placement: .home)
                            .frame(maxWidth: .infinity)
                    }
                    lettersOverview
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
                .frame(maxWidth: 1180)
                .frame(maxWidth: .infinity)
            }
            .background(Color.paper)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .modeEntry(let mode):
                    ModeEntryView(mode: mode, path: $path)
                case .letters(let mode):
                    LetterPickerView(mode: mode)
                case .write(let mode, let templateID):
                    WritingView(mode: mode, templateID: templateID)
                case .recorder:
                    RecorderView()
                }
            }
        }
        .tint(Color.ink)
    }

    /// Goes to a mode: through the ad screen when an ad is available, straight
    /// to the letters otherwise.
    private func open(_ mode: WritingMode) {
        path.append(settings.showAdPlaceholders ? .modeEntry(mode) : .letters(mode))
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Penwise")
                    .font(.system(size: 42, weight: .bold, design: .serif))
                    .foregroundStyle(Color.ink)
                Text("Your handwriting workbook")
                    .font(.workbook(.title3, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("Letter style", selection: $settings.style) {
                ForEach(LetterStyle.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            if progress.streak > 0 {
                Label("\(progress.streak) day\(progress.streak == 1 ? "" : "s")", systemImage: "flame.fill")
                    .font(.headline)
                    .foregroundStyle(Color.orange)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .paperCard(radius: 14)
            }
        }
    }

    // MARK: - First tap

    @ViewBuilder
    private var primaryAction: some View {
        if let last = progress.lastPlayed, let template = library.template(id: last.templateID) {
            actionCard(
                eyebrow: "Pick up where you left off",
                title: "Continue \(last.mode.rawValue) · \(template.spokenName)",
                template: template,
                color: last.mode.color,
                route: .write(last.mode, template.id)
            )
        } else if let first = letters.first {
            actionCard(
                eyebrow: "New here? Begin with the first letter",
                title: "Start with \(first.glyph)",
                template: first,
                color: WritingMode.learn.color,
                route: .write(.learn, first.id)
            )
        }
    }

    private func actionCard(eyebrow: String, title: String, template: LetterTemplate, color: Color, route: Route) -> some View {
        Button { path.append(route) } label: {
            HStack(spacing: 20) {
                LetterThumbnail(template: template, lineWidth: 4, color: .white)
                    .frame(width: 76, height: 80)
                    .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(eyebrow)
                        .font(.subheadline.weight(.semibold))
                        .opacity(0.85)
                    Text(title)
                        .font(.workbook(.title))
                }
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 40))
            }
            .foregroundStyle(.white)
            .padding(20)
            .background(color, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: - Modes

    private var modes: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Choose a mode")
                .font(.workbook(.title2))
                .foregroundStyle(Color.ink)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 20)], spacing: 20) {
                ForEach(WritingMode.allCases) { mode in
                    Button { open(mode) } label: {
                        ModeCard(
                            mode: mode,
                            preview: library.previewTemplate(style: settings.style),
                            practiced: progress.practicedCount(mode, templateIDs: letterIDs),
                            total: letterIDs.count
                        )
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    // MARK: - Letters overview

    private var lettersOverview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Your \(settings.style.title.lowercased()) letters")
                    .font(.workbook(.title2))
                    .foregroundStyle(Color.ink)
                Spacer()
                HStack(spacing: 14) {
                    ForEach(WritingMode.allCases) { mode in
                        HStack(spacing: 5) {
                            Circle().fill(mode.color).frame(width: 9, height: 9)
                            Text("\(mode.rawValue) passed")
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(letters) { template in
                        Button { path.append(.write(suggestedMode(for: template), template.id)) } label: {
                            VStack(spacing: 8) {
                                LetterThumbnail(template: template, lineWidth: 3)
                                    .frame(width: 56, height: 60)
                                HStack(spacing: 5) {
                                    ForEach(WritingMode.allCases) { mode in
                                        Circle()
                                            .fill(isPassed(mode, template) ? mode.color : Color.secondary.opacity(0.25))
                                            .frame(width: 8, height: 8)
                                    }
                                }
                            }
                            .frame(width: 84, height: 100)
                            .paperCard(radius: 18)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(2)
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

private struct ModeCard: View {
    let mode: WritingMode
    let preview: LetterTemplate?
    let practiced: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            WorksheetPreview(template: preview, mode: mode)
                .frame(height: 170)
            HStack(spacing: 10) {
                Image(systemName: mode.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(mode.color)
                Text(mode.rawValue)
                    .font(.workbook(.title))
                    .foregroundStyle(Color.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            Text(mode.subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(practiced) of \(total) letters practised")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(mode.color)
        }
        .padding(16)
        .paperCard(radius: 24)
    }
}
