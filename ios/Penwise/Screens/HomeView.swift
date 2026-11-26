import SwiftUI

/// Home tells the learner what to write next: the journey card first, then
/// Learn, Practice and Test as direct routes, then the banner ad.
struct HomeView: View {
    @ObservedObject private var progress = ProgressStore.shared
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var journeys = JourneyStore.shared
    @State private var path: [Route] = []
    @State private var greeting = 0
    private let greetings: [FoxPose] = [.splash, .tap, .sneeze, .pencilBonk, .dizzy, .sleepy, .hello]

    @State private var showSettings = false

    private let library = TemplateLibrary.shared

    private var journey: Journey? { JourneyLibrary.shared.journey(style: settings.style) }

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { geo in
                let compact = geo.size.width < 540
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        if let journey {
                            journeyCard(journey)
                        }
                        courseShelf(compact: compact)
                        modeShortcuts
                        if AdSlot.shouldAppear {
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
                ToolbarItem(placement: .topBarLeading) {
                    Button { path.append(.plan) } label: { Label("Your plan", systemImage: "calendar") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Label("Account", systemImage: "person.crop.circle").labelStyle(.titleAndIcon)
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .navigationDestination(for: Route.self) { route in
                destination(route)
            }
        }
        .tint(Color.courseAccent)
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .entry(let target):
            EntryView(target: target, path: $path)
        case .letters(let mode):
            LetterPickerView(mode: mode)
        case .sentences(let style, let mode, let glyph):
            SentenceWorksheet(style: style, mode: mode, focus: glyph)
        case .write(let mode, let templateID):
            WorksheetView(context: .free(mode, templateID), path: $path)
        case .set(let mode, let title, let ids, let shuffled):
            WorksheetView(context: .set(mode, title, ids, shuffled: shuffled), path: $path)
        case .journeyMap(let id):
            JourneyMapView(journeyID: id, path: $path)
        case .lesson(let position, let review):
            if JourneyLibrary.shared.journey(id: position.journeyID)?.chapter(position.chapterID)?.isCheckpoint == true {
                WorksheetView(context: .lesson(position, review: review), path: $path)
            } else {
                LetterSessionView(position: position, review: review, path: $path)
            }
        case .recap(let id):
            CheckpointRecapView(journeyID: id, path: $path)
        case .recorder:
            RecorderView()
        case .assessment:
            AssessmentView(style: settings.style, path: $path)
        case .report:
            ReportView()
        case .plan:
            PlanView(path: $path)
        case .words(let request):
            WordPracticeView(request: request)
        case .paywall:
            PaywallView()
        }
    }

    /// Goes through the entry (ad) screen when an ad is available, straight to
    /// the destination otherwise. Extra taps while navigating are ignored.
    private func go(_ target: EntryTarget) {
        guard path.isEmpty else { return }
        path.append(AdSlot.shouldAppear ? .entry(target) : target.destination)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            Button {
                greeting = (greeting + 1) % greetings.count
            } label: {
                WorkbookFox(pose: greetings[greeting]).frame(width: 76, height: 76)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Play with the Penwise fox")
            Text("Penwise")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ink)
            Spacer()
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
        let finished = journeys.isFinished(journey)
        let p = journeys.position(in: journey)
        let chapter = journey.chapter(p.chapterID) ?? journey.chapters[0]
        let chapterLetters = journeys.letters(chapter, in: journey)
        let glyph = p.letterIndex < chapterLetters.count ? chapterLetters[p.letterIndex] : (chapterLetters.first ?? "")
        let done = journeys.completedCount(chapter, in: journey)
        return Button {
            path.append(.journeyMap(journey.id))
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(journey.title)
                        .font(.workbook(.largeTitle, weight: .bold))
                    Text("\(chapter.title) · \(done) of \(chapterLetters.count) complete")
                        .font(.headline)
                    ProgressView(value: Double(done), total: Double(max(1, chapterLetters.count)))
                        .tint(.white)
                    Label(finished ? "Review course" : journeys.hasStarted(journey) ? "Continue with \(glyph)" : "Start with \(glyph)", systemImage: "arrow.right.circle.fill")
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .foregroundStyle(Color.black)
                        .background(.white, in: Capsule())
                }
                Spacer(minLength: 0)
                WorkbookFox(pose: .idle)
                    .frame(minWidth: 60, idealWidth: 140, maxWidth: 150, maxHeight: 160)
            }
            .padding(24)
            .foregroundStyle(.white)
            .background(Color.courseFill, in: RoundedRectangle(cornerRadius: 26))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
    }

    private func courseShelf(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your courses").font(.workbook(.title))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: compact ? 1 : 3), spacing: 14) {
                ForEach(LetterStyle.allCases) { style in
                    if let course = JourneyLibrary.shared.journey(style: style) {
                        courseCover(style, course: course)
                    }
                }
            }
        }
    }

    private func courseCover(_ style: LetterStyle, course: Journey) -> some View {
        let color: Color = {
            switch style {
            case .print: return .courseApricot
            case .cursive: return .courseMint
            case .traditional: return .courseRose
            }
        }()
        let position = journeys.position(in: course)
        let chapters = course.chapters.filter { !$0.isCheckpoint }
        let total = chapters.reduce(0) { $0 + $1.letters.count }
        let completed = chapters.reduce(0) { $0 + journeys.completedCount($1, in: course) }
        return Button {
            settings.style = style
            path.append(.journeyMap(course.id))
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(style.title).font(.workbook(.largeTitle, weight: .bold))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                HStack(spacing: 3) {
                    ForEach(["a", "l", "g"].compactMap { library.template(id: course.templateID($0)) }) { template in
                        LetterThumbnail(template: template, lineWidth: 3, color: .ink)
                            .frame(maxWidth: 62)
                    }
                }
                .frame(height: 72)
                if let chapter = course.chapter(position.chapterID) {
                    Text(chapter.title).font(.headline)
                    ProgressView(value: Double(completed), total: Double(max(total, 1)))
                        .tint(Color.courseAccent)
                    Text("\(completed) of \(total) course letters complete")
                        .font(.subheadline)
                }
            }
            .padding(20)
            .padding(.leading, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color)
            .overlay(alignment: .leading) {
                Rectangle().fill(Color.ink.opacity(0.12)).frame(width: 7)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .foregroundStyle(Color.ink)
        }
        .buttonStyle(PressableStyle())
    }

    private var modeShortcuts: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(settings.style.title) shortcuts").font(.workbook(.headline))
            HStack {
                ForEach(WritingMode.selectable) { mode in
                    Button { go(.mode(mode)) } label: {
                        VStack(spacing: 6) {
                            Image(systemName: mode.symbol)
                            Text(mode.rawValue).font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(mode.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }
}
