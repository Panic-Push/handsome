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

    private var journey: Journey? { JourneyLibrary.shared.journey(style: settings.style) }

    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { geo in
                let compact = geo.size.width < 540
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        if let journey, journeys.hasStarted(journey) {
                            journeyCard(journey)
                        }
                        courseShelf(compact: compact)
                        modeShortcuts
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
        let action = "Review your letters"
        let detail = finished ? "Journey complete" : "\(chapter.title) · \(done) of \(chapterLetters.count) complete"

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Continue \(settings.style.title)")
                    .font(.workbook(.largeTitle, weight: .bold))
                Spacer()
                Button { go(.journeyMap(journey.id)) } label: {
                    Image(systemName: "map").padding(8)
                }
                .accessibilityLabel("Open chapter map")
            }
            Text(detail).font(.headline)
            HStack {
                specimen(Array(chapterLetters.prefix(3)), in: journey, current: glyph)
                Spacer(minLength: 0)
                FoxBookmark().frame(width: 62, height: 66).accessibilityHidden(true)
            }
            Button { go(finished ? .journeyMap(journey.id) : .journeyResume(journey.id)) } label: {
                Label(finished ? action : "\(p.step.title) \(glyph)", systemImage: "arrow.right")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.courseViolet)
        }
        .padding(22)
        .background(Color.courseViolet.opacity(0.13), in: RoundedRectangle(cornerRadius: 26))
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

    private func courseShelf(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your courses").font(.workbook(.title))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: compact ? 1 : 2), spacing: 14) {
                ForEach(LetterStyle.allCases) { style in
                    if let course = JourneyLibrary.shared.journey(style: style) {
                        courseCover(style, course: course)
                    }
                }
            }
        }
    }

    private func courseCover(_ style: LetterStyle, course: Journey) -> some View {
        let color = style == .print ? Color.courseApricot : Color.courseMint
        let position = journeys.position(in: course)
        return Button {
            settings.style = style
            go(.journeyMap(course.id))
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(style.title).font(.workbook(.largeTitle, weight: .bold))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                HStack(spacing: 3) {
                    ForEach(library.templates(style: style).prefix(3)) { template in
                        LetterThumbnail(template: template, lineWidth: 3, color: .ink)
                            .frame(maxWidth: 62)
                    }
                }
                .frame(height: 72)
                if let chapter = course.chapter(position.chapterID) {
                    Text(chapter.title).font(.headline)
                    Text("\(journeys.completedCount(chapter, in: course)) of \(journeys.letters(chapter, in: course).count) complete")
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
                ForEach(WritingMode.allCases) { mode in
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

private struct FoxBookmark: View {
    var body: some View {
        Canvas { context, size in
            func facet(_ points: [CGPoint], _ color: Color) {
                var path = Path()
                for (index, point) in points.enumerated() {
                    let vertex = CGPoint(x: point.x * size.width, y: point.y * size.height)
                    if index == 0 { path.move(to: vertex) } else { path.addLine(to: vertex) }
                }
                path.closeSubpath()
                context.fill(path, with: .color(color))
            }
            let nose = CGPoint(x: 0.5, y: 0.90)
            let left = CGPoint(x: 0.08, y: 0.57)
            let right = CGPoint(x: 0.92, y: 0.57)
            let brow = CGPoint(x: 0.5, y: 0.36)
            facet([.init(x: 0, y: 0.05), brow, nose, left], .orange)
            facet([.init(x: 1, y: 0.05), right, nose, brow], Color(red: 0.91, green: 0.43, blue: 0.19))
            facet([left, .init(x: 0.27, y: 0.53), nose], .white)
            facet([right, .init(x: 0.73, y: 0.53), nose], .white)
            facet([.init(x: 0.44, y: 0.83), .init(x: 0.56, y: 0.83), nose], .black)
        }
    }
}
