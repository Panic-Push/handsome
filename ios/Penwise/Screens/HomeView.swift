import SwiftUI

/// Home tells the learner what to write next: the journey card first, then
/// Learn, Practice and Test as direct routes, then the banner ad.
struct HomeView: View {
    @ObservedObject private var progress = ProgressStore.shared
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var journeys = JourneyStore.shared
    @State private var path: [Route] = []
    @State private var showSettings = false

    private let library = TemplateLibrary.shared

    private var letters: [LetterTemplate] { library.templates(style: settings.style) }
    private var letterIDs: [String] { letters.map(\.id) }
    private var journey: Journey? { JourneyLibrary.shared.journey(style: settings.style) }

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { geo in
                let landscape = geo.size.width > geo.size.height
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        if let journey {
                            journeyCard(journey)
                        }
                        modes(landscape: landscape)
                        if settings.showAdPlaceholders {
                            AdSlot(placement: .home)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 20)
                    .frame(maxWidth: 1180)
                    .frame(maxWidth: .infinity)
                }
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
                destination(route)
            }
        }
        .tint(Color.ink)
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .entry(let target):
            EntryView(target: target, path: $path)
        case .letters(let mode):
            LetterPickerView(mode: mode)
        case .write(let mode, let templateID):
            WorksheetView(context: .free(mode, templateID), path: $path)
        case .journeyMap(let id):
            JourneyMapView(journeyID: id, path: $path)
        case .lesson(let position, let review):
            WorksheetView(context: .lesson(position, review: review), path: $path)
        case .recap(let id):
            CheckpointRecapView(journeyID: id, path: $path)
        case .recorder:
            RecorderView()
        }
    }

    /// Goes through the entry (ad) screen when an ad is available, straight to
    /// the destination otherwise. Extra taps while navigating are ignored.
    private func go(_ target: EntryTarget) {
        guard path.isEmpty else { return }
        path.append(settings.showAdPlaceholders ? .entry(target) : target.destination)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            Text("Penwise")
                .font(.system(size: 30, weight: .bold, design: .serif))
                .foregroundStyle(Color.ink)
            Spacer()
            Picker("Letter style", selection: $settings.style) {
                ForEach(LetterStyle.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            HStack(spacing: 12) {
                Label("\(progress.streak)", systemImage: "flame.fill")
                    .foregroundStyle(Color.orange)
                Divider().frame(height: 18)
                Text("\(progress.attemptsToday) today")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .paperCard(radius: 14)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(progress.streak) day streak, \(progress.attemptsToday) letters today")
        }
    }

    // MARK: - Journey card

    private func journeyCard(_ journey: Journey) -> some View {
        let started = journeys.hasStarted(journey)
        let finished = journeys.isFinished(journey)
        let p = journeys.position(in: journey)
        let chapter = journey.chapter(p.chapterID) ?? journey.chapters[0]
        let chapterLetters = journeys.letters(chapter, in: journey)
        let glyph = p.letterIndex < chapterLetters.count ? chapterLetters[p.letterIndex] : (chapterLetters.first ?? "")
        let done = journeys.completedCount(chapter, in: journey)
        let action = finished ? "Review your letters" : started ? "Continue with \(glyph)" : "Start with \(glyph)"
        let detail = finished ? "Journey complete" : "\(chapter.title) · \(done) of \(chapterLetters.count) complete"

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("YOUR JOURNEY")
                        .font(.caption.weight(.semibold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                    Text(journey.title)
                        .font(.system(size: 30, weight: .bold, design: .serif))
                        .foregroundStyle(Color.ink)
                    Label(detail, systemImage: finished ? "checkmark.seal.fill" : "book.closed")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(finished ? Color.green : Color.secondary)
                }
                Spacer()
                Button { go(.journeyMap(journey.id)) } label: {
                    Label("Chapter map", systemImage: "map")
                }
                .buttonStyle(.bordered)
            }
            HStack(alignment: .bottom, spacing: 20) {
                specimen(chapter.isCheckpoint ? Array(chapter.letters.prefix(4)) : chapterLetters, in: journey, current: started ? glyph : nil)
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 8) {
                    if started && !finished {
                        Text("\(glyph) · \(p.step.title)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Button { go(finished ? .journeyMap(journey.id) : .journeyResume(journey.id)) } label: {
                        Label(action, systemImage: "arrow.right")
                            .font(.headline)
                            .frame(minWidth: 220)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(WritingMode.learn.color)
                    .controlSize(.large)
                }
            }
        }
        .padding(24)
        .paperCard(radius: 26)
    }

    /// The chapter's letters drawn from the real templates on a ruled strip.
    private func specimen(_ glyphs: [String], in journey: Journey, current: String?) -> some View {
        HStack(spacing: 4) {
            ForEach(glyphs, id: \.self) { g in
                if let template = library.template(id: journey.templateID(g)) {
                    LetterThumbnail(template: template, lineWidth: 3.5,
                                    color: current == nil || current == g ? .ink : .ink.opacity(0.4))
                        .frame(width: 60, height: 72)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(
            ZStack {
                Color.paper
                VStack(spacing: 0) {
                    Spacer()
                    Rectangle().fill(Color.rule.opacity(0.6)).frame(height: 1.5)
                    Spacer().frame(height: 22)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        )
    }

    // MARK: - Mode cards

    private func modes(landscape: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Practice by mode")
                .font(.workbook(.title2))
                .foregroundStyle(Color.ink)
            if landscape {
                HStack(alignment: .top, spacing: 20) {
                    ForEach(WritingMode.allCases) { mode in
                        modeButton(mode, compact: false)
                    }
                }
            } else {
                VStack(spacing: 14) {
                    ForEach(WritingMode.allCases) { mode in
                        modeButton(mode, compact: true)
                    }
                }
            }
        }
    }

    private func modeButton(_ mode: WritingMode, compact: Bool) -> some View {
        Button { go(.mode(mode)) } label: {
            ModeCard(
                mode: mode,
                preview: library.previewTemplate(style: settings.style),
                practiced: progress.practicedCount(mode, templateIDs: letterIDs),
                total: letterIDs.count,
                compact: compact
            )
        }
        .buttonStyle(PressableStyle())
    }
}

private struct ModeCard: View {
    let mode: WritingMode
    let preview: LetterTemplate?
    let practiced: Int
    let total: Int
    let compact: Bool

    var body: some View {
        Group {
            if compact {
                HStack(spacing: 18) {
                    WorksheetPreview(template: preview, mode: mode)
                        .frame(width: 220, height: 120)
                    text
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    WorksheetPreview(template: preview, mode: mode)
                        .frame(height: 160)
                    text
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(radius: 24)
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: mode.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(mode.color)
                Text(mode.rawValue)
                    .font(.workbook(.title))
                    .foregroundStyle(Color.ink)
            }
            Text(mode.cardLabel)
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("\(practiced) of \(total) practiced")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(mode.color)
        }
    }
}
