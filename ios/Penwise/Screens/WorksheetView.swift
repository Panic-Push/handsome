import SwiftUI
import UIKit

/// What a worksheet is for: free practice of one letter in a mode, or a step
/// of a journey lesson.
enum WorksheetContext: Hashable {
    case free(WritingMode, String)
    case set(WritingMode, String, [String], shuffled: Bool = false)
    case lesson(LessonPosition, review: Bool)
}

/// The worksheet: write a letter and it is scored automatically after a short
/// pause, with one specific correction. The page never moves when feedback
/// appears; the learner decides when to retry or move on.
struct WorksheetView: View {
    private enum GuideKind { case learn, faint, memory }

    struct Attempt {
        let strokes: [CapturedStroke]
        let result: ScoreResult
        let hinted: Bool
    }

    /// Pause after a lift before scoring, and the longer pause while a dot,
    /// crossbar or other stroke is probably still coming. Tuning defaults.
    private static let pause: TimeInterval = 0.6
    private static let finishingPause: TimeInterval = 1.2

    @Binding var path: [Route]
    private let review: Bool
    private let setTitle: String?
    @State private var setLetters: [String] = []
    @State private var setIndex = 0
    @State private var setScores: [Int] = []
    @State private var completedSet = false
    @State private var rowIndex = 0
    @State private var rowSamples: [Int: [CapturedStroke]] = [:]

    @StateObject private var ink = InkModel()
    @ObservedObject private var progress = ProgressStore.shared
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var journeys = JourneyStore.shared

    @State private var freeMode: WritingMode
    @State private var freeTemplateID: String
    @State private var position: LessonPosition?

    @State private var peek = false
    @State private var usedHint = false
    @State private var canvasSize: CGSize = .zero

    @State private var result: ScoreResult?
    @State private var currentAttempt: Attempt?
    @State private var rowTip: String?
    @State private var previousAttempt: Attempt?
    @State private var committed = false
    @State private var comparison: Comparison?
    @State private var checking = false
    @State private var pendingScore: DispatchWorkItem?
    /// Changes whenever the exercise or attempt changes, so late results are dropped.
    @State private var exercise = UUID()

    @State private var errorText: String?
    @State private var notice: String?
    @State private var demoStart: Date?
    @State private var pendingAdvance: DispatchWorkItem?
    @State private var showDetails = false

    private let library = TemplateLibrary.shared

    init(context: WorksheetContext, path: Binding<[Route]>) {
        _path = path
        switch context {
        case .set(let mode, let title, let ids, let shuffled):
            setTitle = title
            _setLetters = State(initialValue: shuffled ? ids.shuffled() : ids)
            _freeMode = State(initialValue: mode)
            _freeTemplateID = State(initialValue: "")
            _position = State(initialValue: nil)
            review = false
        case .free(let mode, let id):
            setTitle = nil
            _freeMode = State(initialValue: mode)
            _freeTemplateID = State(initialValue: id)
            _position = State(initialValue: nil)
            review = false
        case .lesson(let p, let isReview):
            setTitle = nil
            _freeMode = State(initialValue: p.step.mode)
            _freeTemplateID = State(initialValue: "")
            _position = State(initialValue: p)
            review = isReview
        }
    }

    // MARK: - Derived

    private var journey: Journey? { position.flatMap { JourneyLibrary.shared.journey(id: $0.journeyID) } }

    private var chapter: Journey.Chapter? {
        guard let p = position, let j = journey else { return nil }
        return j.chapter(p.chapterID)
    }

    private var lessonLetters: [String] {
        guard let j = journey, let c = chapter else { return [] }
        return journeys.letters(c, in: j)
    }

    private var lessonGlyph: String? {
        guard let p = position, p.letterIndex < lessonLetters.count else { return nil }
        return lessonLetters[p.letterIndex]
    }

    private var templateID: String {
        if let j = journey, let g = lessonGlyph { return j.templateID(g) }
        if setLetters.indices.contains(setIndex) { return setLetters[setIndex] }
        return freeTemplateID
    }

    private var selected: LetterTemplate? { library.template(id: templateID) }
    private var mode: WritingMode {
        if let step = position?.step { return step.mode }
        if usesRow {
            let modes: [WritingMode] = [.learn, .practice, .test]
            return modes[slot]
        }
        return freeMode
    }

    private var usesRow: Bool { position == nil ? freeMode != .test : chapter?.isCheckpoint == false }

    private var slot: Int {
        guard let step = position?.step else { return rowIndex }
        switch step {
        case .watch, .trace: return 0
        case .guided: return 1
        case .memory: return 2
        }
    }
    private var isLesson: Bool { position != nil }

    private var freeLetters: [LetterTemplate] {
        library.templates(style: selected?.style ?? settings.style.rawValue)
    }

    private var guideKind: GuideKind {
        if !usesRow { return .memory }
        let guides: [GuideKind] = [.learn, .faint, .memory]
        return guides[slot]
    }

    private var title: String {
        if let setTitle { return "\(setTitle) · \(setIndex + 1) of \(setLetters.count)" }
        if let p = position, let c = chapter, let g = lessonGlyph {
            return "\(c.title) · \(g) · \(p.step.title)"
        }
        return "\(freeMode.rawValue) · \(selected?.spokenName ?? "")"
    }

    /// Fewest strokes any accepted form of the letter uses.
    private var expectsMoreStrokes: Bool {
        guard let t = selected else { return false }
        let counts = [t.strokes.count] + (t.alternates ?? []).map(\.count)
        return ink.strokeCount < (counts.min() ?? 1)
    }

    private func makeLayout(_ size: CGSize) -> GuideLayout {
        GuideLayout.fit(
            in: size,
            letterWidth: CGFloat(selected?.width ?? 0.5),
            large: settings.size == .large,
            leftHanded: settings.handedness == .left
        )
    }

    private var layout: GuideLayout { makeLayout(canvasSize) }

    // MARK: - Body

    var body: some View {
        Group {
            if completedSet {
                setRecap
            } else {
                VStack(spacing: 12) {
                    if usesRow {
                        practiceRow
                    } else {
                        page
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }
                    VStack(spacing: 8) {
                        ScrollView {
                            status.frame(maxWidth: 740, alignment: .leading)
                        }
                        .frame(height: 96)
                        actions.frame(maxWidth: 550)
                    }
                    .padding(12)
                    .frame(height: 220, alignment: .top)
                    .background(Color.paperCard, in: RoundedRectangle(cornerRadius: 18))
                }
                .padding(14)
                .background(Color.courseViolet.opacity(0.85))
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let position, let steps = chapter?.steps, let index = steps.firstIndex(of: position.step) {
                ProgressView(value: Double(index + 1), total: Double(steps.count))
                    .tint(Color.courseViolet)
                    .accessibilityLabel("Lesson step")
                    .accessibilityValue("\(index + 1) of \(steps.count)")
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { if !completedSet { toolbarContent } }
        .onAppear(perform: appear)
        .onDisappear {
            cancelPending()
            commitIfNeeded()
        }
        .onChange(of: ink.revision) { _, _ in inkChanged() }
        .onChange(of: ink.isDrawing) { _, drawing in drawingChanged(drawing) }
        .onChange(of: showDetails) { _, open in
            if !open && result != nil { scheduleAdvance(revision: ink.revision, token: exercise) }
        }
        .onChange(of: peek) { _, isOn in if isOn { usedHint = true } }
        .onChange(of: ink.pencilOnly) { _, value in settings.pencilOnly = value }
        .onChange(of: settings.size) { _, _ in startOver() }
        .onChange(of: settings.handedness) { _, _ in startOver() }
    }

    // MARK: - Page

    private var practiceRow: some View {
        GeometryReader { bounds in
            let gap: CGFloat = 4
            let width = (bounds.size.width - 2 * gap) / 3
            let height = max(48, min(bounds.size.height - 30, width * 1.8))
            let area = CGSize(width: width, height: height)
            let guides = makeLayout(area)
            VStack(spacing: 6) {
                HStack(spacing: gap) {
                    ForEach(0..<3) { index in
                        Text(["Trace", "Light guide", "Memory"][index])
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(index == slot ? Color.white : Color.white.opacity(0.8))
                            .frame(width: width)
                    }
                }
                ZStack(alignment: .leading) {
                    HStack(spacing: gap) {
                        ForEach(0..<3) { index in
                            ZStack {
                                Color.paper
                                RuledLinesView(layout: guides)
                                if let sample = rowSamples[index] {
                                    Canvas { context, _ in
                                        for stroke in sample {
                                            var path = Path()
                                            path.addLines(stroke.points.map {
                                                guides.toScreen(CGPoint(x: $0.x, y: $0.y))
                                            })
                                            context.stroke(path, with: .color(.ink), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                        }
                                    }
                                } else if index != slot, index < 2, let template = selected {
                                    TemplateOverlay(template: template, layout: guides, showArrows: false,
                                                    showDots: false, pathOpacity: 0.16, solidPath: true)
                                }
                            }
                            .frame(width: width, height: height)
                            .clipped()
                        }
                    }
                    page
                        .frame(width: width, height: height)
                        .clipped()
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.courseViolet, lineWidth: 3)
                            .allowsHitTesting(false))
                        .offset(x: CGFloat(slot) * (width + gap))
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var setRecap: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal.fill").font(.largeTitle).foregroundStyle(Color.courseViolet)
            Text("\(setTitle ?? "Session") complete").font(.workbook(.largeTitle))
            Text("\(setScores.count) letters · Average \(setScores.reduce(0, +) / max(1, setScores.count)) / 100")
            Button("Back to activities") { if !path.isEmpty { path.removeLast() } }
                .buttonStyle(.borderedProminent).controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.paper)
    }

    private var page: some View {
        GeometryReader { geo in
            let layout = makeLayout(geo.size)
            ZStack(alignment: .topLeading) {
                Color.paper
                RuledLinesView(layout: layout, highlighted: highlightedLines)
                if let template = selected {
                    guide(for: template, layout: layout)
                    if guideKind != .memory, result != nil, let previous = previousAttempt {
                        AttemptGhost(strokes: previous.strokes, layout: layout)
                    }
                    if let start = demoStart {
                        StrokeDemoView(template: template, layout: layout, start: start, color: mode.color)
                    }
                }
                InkCanvas(model: ink)
                if !usesRow, mode == .test, let template = selected {
                    TargetLetterCard(template: template, hinted: usedHint)
                        .padding(16)
                }
            }
            .onAppear { canvasSize = geo.size }
            .onChange(of: geo.size) { _, newSize in
                canvasSize = newSize
                startOver() // the guides moved, so old ink would no longer line up
            }
        }
    }

    @ViewBuilder
    private func guide(for template: LetterTemplate, layout: GuideLayout) -> some View {
        let highlight = result?.problemStrokes ?? []
        switch guideKind {
        case .learn:
            TemplateOverlay(template: template, layout: layout, highlight: highlight)
        case .faint:
            TemplateOverlay(template: template, layout: layout, showArrows: false, showDots: false,
                            pathOpacity: slot == 0 ? 0.45 : 0.20, solidPath: true, highlight: highlight)
        case .memory:
            TemplateOverlay(template: template, layout: layout, showPath: peek, showArrows: peek,
                            showDots: peek, highlight: peek ? highlight : [])
        }
    }

    /// Ruled lines to mark in red for the current correction.
    private var highlightedLines: [CGFloat] {
        guard let kind = result?.primaryKind, let template = selected else { return [] }
        switch kind {
        case "OFF_BASELINE": return [1.0]
        case "TOO_BIG", "TOO_SMALL": return [template.topY < 0.25 ? 0.0 : 0.5]
        default: return []
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if !isLesson && setTitle == nil {
                letterMenu
            }

            if guideKind != .memory {
                Button { replayDemo() } label: {
                    Label(guideKind == .memory ? "Replay" : "Watch again", systemImage: "play.circle")
                }
            }

            if guideKind == .memory {
                Toggle(isOn: $peek) {
                    Label("Peek", systemImage: peek ? "eye" : "eye.slash")
                }
                .toggleStyle(.button)
            }

            Button { ink.undo() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                .disabled(ink.strokeCount == 0)
            Button(role: .destructive) { tryAgain() } label: { Label("Clear", systemImage: "trash") }
                .disabled(ink.strokeCount == 0)

            if let template = selected, let style = LetterStyle(rawValue: template.style) {
                Button {
                    cancelPending()
                    path.append(.sentences(style, .practice, template.glyph))
                } label: { Label("Practice in a sentence", systemImage: "text.word.spacing") }
            }
            optionsMenu
        }
    }

    private var letterMenu: some View {
        Menu {
            ForEach(freeLetters) { template in
                Button { selectFree(template.id) } label: {
                    if template.id == templateID {
                        Label(template.spokenName, systemImage: "checkmark")
                    } else {
                        Text(template.spokenName)
                    }
                }
            }
        } label: {
            Label("Letter", systemImage: "textformat.abc")
        }
    }

    private var optionsMenu: some View {
        Menu {
            if !isLesson && setTitle == nil {
                Picker("Mode", selection: freeModeBinding) {
                    ForEach(WritingMode.selectable) { Label($0.rawValue, systemImage: $0.symbol).tag($0) }
                }
            }
            Picker("Writing size", selection: $settings.size) {
                ForEach(WritingSize.allCases) { Text($0.title).tag($0) }
            }
            Picker("Writing hand", selection: $settings.handedness) {
                ForEach(Handedness.allCases) { Text($0.title).tag($0) }
            }
            Toggle("Apple Pencil only", isOn: $ink.pencilOnly)
        } label: {
            Label("Options", systemImage: "ellipsis.circle")
        }
    }

    /// Saves the current attempt under the old mode before switching.
    private var freeModeBinding: Binding<WritingMode> {
        Binding(
            get: { freeMode },
            set: { newMode in
                guard newMode != freeMode else { return }
                commitIfNeeded()
                rowIndex = 0
                rowSamples.removeAll()
                freeMode = newMode
                resetLetter()
                if newMode == .learn { startDemo() }
            }
        )
    }

    // MARK: - Feedback rail

    private func rail(landscape: Bool) -> some View {
        Group {
            if landscape {
                VStack(alignment: .leading, spacing: 20) {
                    if isLesson { stepChips }
                    status
                    Spacer(minLength: 0)
                    actions
                }
                .padding(24)
            } else {
                HStack(alignment: .center, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        if isLesson { stepChips }
                        status
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    actions
                        .frame(width: 230)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.paperCard)
    }

    private var stepChips: some View {
        HStack(spacing: 6) {
            ForEach(chapter?.steps ?? [], id: \.self) { step in
                let isCurrent = step == position?.step
                Text(step.title)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(isCurrent ? mode.color.opacity(0.18) : Color.secondary.opacity(0.08), in: Capsule())
                    .foregroundStyle(isCurrent ? mode.color : Color.secondary)
            }
        }
    }

    @ViewBuilder
    private var status: some View {
        if let result = result {
            feedback(result)
        } else {
            prompt
        }
    }

    private var instruction: String {
        if let errorText { return errorText }
        let name = lessonGlyph ?? selected?.glyph ?? "letter"
        if let step = position?.step {
            switch step {
            case .watch: return "Watch how the \(name) is written. Start tracing whenever you're ready."
            case .guided: return "Follow the faint letter. The next space is yours to write from memory."
            case .trace: return "Trace the \(name) from the green dot, following the arrow."
            case .memory: return "Write the \(name) from memory."
            }
        }
        if usesRow {
            return ["Trace the \(name) from the start dot.", "Follow the light guide for \(name).", "Write \(name) from memory."][slot]
        }
        switch freeMode {
        case .learn: return "Trace the \(name) from the green dot, following the arrow."
        case .practice:
            return "Follow the guide."
        case .test: return "Write the \(selected?.spokenName ?? name) from memory."
        }
    }

    private var prompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let notice {
                Label(notice, systemImage: "flag.checkered")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.green)
            }
            if let rowTip, usesRow && slot > 0 {
                Label(rowTip, systemImage: "pencil.tip").font(.callout)
            }
            Text(instruction)
                .font(.workbook(.title2))
                .foregroundStyle(errorText == nil ? Color.ink : Color.red)
                .fixedSize(horizontal: false, vertical: true)
            if checking {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Checking your letter…")
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
            } else if ink.strokeCount == 0 {
                Text("It's checked automatically when you pause.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if guideKind == .memory && usedHint {
                Text("You peeked, so this try is saved as With hint.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func feedback(_ r: ScoreResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(r.tip == nil ? "Looks great" : "One thing to work on",
                  systemImage: r.tip == nil ? "checkmark.seal.fill" : "lightbulb.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(r.tip == nil ? Color.green : mode.color)
            Text(r.tip ?? goodMessage(r.overall))
                .font(.workbook(.title2))
                .foregroundStyle(Color.ink)
                .lineLimit(4)
                .minimumScaleFactor(0.75)
            if let comparison {
                Label(comparison.text, systemImage: comparison.improved ? "arrow.up.right.circle.fill" : "equal.circle")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(comparison.improved ? Color.green : Color.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            HStack(spacing: 14) {
                StarsView(count: ProgressStore.stars(for: r.overall), size: 15, animated: true)
                Button { cancelPending(); showDetails = true } label: {
                    Text("Details · \(r.overall)")
                        .font(.callout.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .popover(isPresented: $showDetails) {
                    ScoreDetailsView(result: r, history: progress.recentAttempts(mode, templateID))
                }
                if guideKind == .memory && usedHint {
                    Text("With hint")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.2), in: Capsule())
                }
            }
        }
    }

    @ViewBuilder
    private var actions: some View {
        if result != nil {
            VStack(spacing: 8) {
                primaryButton(nextLabel, "arrow.right", action: goNext)
                secondaryButton("Try again", "arrow.counterclockwise", action: tryAgain)
            }
        }
    }

    private func primaryButton(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(mode.color)
        .controlSize(.large)
    }

    private func secondaryButton(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(mode.color)
    }

    private var nextLabel: String {
        if usesRow && slot < 2 { return "Continue practice" }
        if setTitle != nil {
            guard setIndex + 1 < setLetters.count else { return "Finish session" }
            return "Next letter · " + (library.template(id: setLetters[setIndex + 1])?.glyph ?? "")
        }
        guard let p = position, let j = journey else {
            let list = freeLetters
            guard let index = list.firstIndex(where: { $0.id == templateID }), !list.isEmpty else { return "Next letter" }
            return "Next letter · " + list[(index + 1) % list.count].glyph
        }
        let next = journeys.next(after: p, in: j)
        guard let next else { return "See recap" }
        if next.chapterID != p.chapterID { return "Finish chapter" }
        if next.letterIndex != p.letterIndex { return "Next letter · " + lessonLetters[next.letterIndex] }
        return "Next step: \(next.step.title)"
    }

    // MARK: - Automatic scoring

    private func inkChanged() {
        cancelPending()
        if result != nil {
            result = nil // the ink changed, so the old feedback is stale
        }
        guard ink.strokeCount > 0 else { return }
        if !ink.isDrawing { schedule() }
    }

    private func drawingChanged(_ drawing: Bool) {
        if drawing {
            cancelPending()
            result = nil
            currentAttempt = nil
            demoStart = nil
            notice = nil
            if ink.strokeCount == 0 { usedHint = peek } // a new attempt begins
            beginTraceIfWatching()
        } else if ink.strokeCount > 0 && result == nil {
            schedule()
        }
    }

    private func schedule() {
        cancelPending()
        let revision = ink.revision
        let token = exercise
        guard !completedSet else { return }
        let delay = expectsMoreStrokes ? WorksheetView.finishingPause : WorksheetView.pause
        checking = true
        let work = DispatchWorkItem { scoreNow(revision: revision, token: token) }
        pendingScore = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func cancelPending() {
        pendingAdvance?.cancel()
        pendingAdvance = nil
        pendingScore?.cancel()
        pendingScore = nil
        checking = false
    }

    /// Scores a snapshot, and shows it only if the ink and exercise still match.
    private func scoreNow(revision: Int, token: UUID) {
        guard token == exercise, revision == ink.revision, !ink.isDrawing, ink.strokeCount > 0 else { return }
        pendingScore = nil
        checking = false
        guard let template = selected, let json = library.json(for: template.id) else {
            errorText = "This letter's template is missing."
            return
        }
        let strokes = ink.capturedStrokes(in: layout)
        do {
            let score = try CoreBridge.score(
                strokes: strokes,
                templateID: template.id,
                templateJSON: json,
                mode: mode,
                finger: ink.lastInkUsedFinger
            )
            errorText = nil
            comparison = previousAttempt.flatMap { Comparison.make(previous: $0.result, current: score, glyph: template.glyph) }
            currentAttempt = Attempt(strokes: strokes, result: score, hinted: guideKind == .memory && usedHint)
            committed = false
            result = score
            react(to: score.overall)
            if !showDetails { scheduleAdvance(revision: revision, token: token) }
        } catch {
            errorText = "Could not score this letter: \(error.localizedDescription)"
        }
    }

    /// Feedback stays visible while the pen is up. Any new stroke cancels the move.
    private func scheduleAdvance(revision: Int, token: UUID) {
        pendingAdvance?.cancel()
        let unfinished = expectsMoreStrokes || result?.primaryKind == "MISSING_STROKE" || result?.primaryKind == "INCOMPLETE"
        let delay: TimeInterval = unfinished ? 2.4 : (usesRow && slot < 2 ? 0.35 : 1.0)
        let work = DispatchWorkItem {
            guard token == exercise, revision == ink.revision, !ink.isDrawing,
                  result != nil, !showDetails, !completedSet else { return }
            goNext()
        }
        pendingAdvance = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// Saves the latest scored version of this attempt to progress, once.
    private func commitIfNeeded() {
        guard let attempt = currentAttempt, result != nil, !committed else { return }
        committed = true
        progress.record(score: attempt.result.overall, mode: mode, templateID: templateID,
                        hinted: attempt.hinted, issue: attempt.result.primaryKind)
        if let j = journey, let g = lessonGlyph, position?.step == .memory {
            journeys.noteMemoryAttempt(journey: j, glyph: g, strokes: attempt.strokes,
                                       score: attempt.result.overall, issue: attempt.result.primaryKind)
        }
    }

    // MARK: - Actions

    private func appear() {
        ink.pencilOnly = settings.pencilOnly
        if let p = position, let j = journey {
            if let c = j.chapter(p.chapterID), c.isCheckpoint {
                journeys.lockCheckpointPicks(c, in: j)
            }
            if !review { journeys.setPosition(p) }
            if p.step == .watch { startDemo() }
        } else if freeMode == .learn {
            startDemo()
        }
    }

    /// Another try at the same letter. The scored attempt is saved and kept
    /// for comparison with the next one.
    private func tryAgain() {
        cancelPending()
        commitIfNeeded()
        if let attempt = currentAttempt { previousAttempt = attempt }
        currentAttempt = nil
        comparison = nil
        result = nil
        demoStart = nil
        exercise = UUID()
        ink.clear()
    }

    /// Clears everything for a fresh start (layout changed or new exercise).
    private func startOver() {
        cancelPending()
        commitIfNeeded()
        currentAttempt = nil
        previousAttempt = nil
        comparison = nil
        result = nil
        exercise = UUID()
        ink.clear()
    }

    private func resetLetter() {
        demoStart = nil
        errorText = nil
        peek = false
        usedHint = false
        startOver()
    }

    private func advanceWithinRow() {
        guard let attempt = currentAttempt, slot < 2 else { return }
        rowTip = attempt.result.tip
        rowSamples[slot] = attempt.strokes
        if isLesson {
            advanceLesson()
        } else {
            commitIfNeeded()
            rowIndex += 1
            resetLetter()
        }
    }

    private func goNext() {
        cancelPending()
        if usesRow && slot < 2 {
            advanceWithinRow()
            return
        }
        if !isLesson && usesRow && slot == 2, let template = selected,
           let style = LetterStyle(rawValue: template.style),
           let course = JourneyLibrary.shared.journey(style: style),
           let unit = course.chapters.first(where: { !$0.isCheckpoint && $0.letters.contains(template.glyph) }),
           let index = unit.letters.firstIndex(of: template.glyph) {
            for step in unit.scoredSteps {
                journeys.markComplete(LessonPosition(journeyID: course.id, chapterID: unit.id,
                                                     letterIndex: index, step: step), glyph: template.glyph)
            }
        }
        if setTitle != nil {
            guard let attempt = currentAttempt else { return }
            commitIfNeeded()
            setScores.append(attempt.result.overall)
            if setIndex + 1 == setLetters.count {
                completedSet = true
            } else {
                setIndex += 1
                rowIndex = 0
                rowSamples.removeAll()
                resetLetter()
            }
            return
        }
        if isLesson {
            advanceLesson()
        } else {
            let all = freeLetters
            guard !all.isEmpty, let i = all.firstIndex(where: { $0.id == templateID }) else { return }
            selectFree(all[(i + 1) % all.count].id)
        }
    }

    private func selectFree(_ id: String) {
        guard id != freeTemplateID else { return }
        commitIfNeeded()
        rowIndex = 0
        rowSamples.removeAll()
        freeTemplateID = id
        resetLetter()
        if freeMode == .learn { startDemo() }
    }

    /// Completes this step and moves to the next one: next step of the letter,
    /// next letter, next chapter, or the recap at the end.
    private func advanceLesson() {
        guard let p = position, let j = journey, let glyph = lessonGlyph else { return }
        cancelPending()
        commitIfNeeded()
        journeys.markComplete(p, glyph: glyph)

        guard let next = journeys.next(after: p, in: j) else {
            if review {
                if !path.isEmpty { path.removeLast() }
                return
            }
            replaceRoute(with: .recap(j.id))
            return
        }
        if next.chapterID != p.chapterID, let nextChapter = j.chapter(next.chapterID) {
            journeys.lockCheckpointPicks(nextChapter, in: j)
            notice = "\(chapter?.title ?? "Chapter") complete. Next: \(nextChapter.title)"
        }
        if !review || journeys.position(in: j) == p { journeys.setPosition(next) }
        if next.chapterID != p.chapterID || next.letterIndex != p.letterIndex { rowSamples.removeAll() }
        position = next
        resetLetter()
        if next.step == .watch { startDemo() }
    }

    private func replaceRoute(with route: Route) {
        if !path.isEmpty { path.removeLast() }
        path.append(route)
    }

    /// The Watch step ends when the demo finishes or the learner starts writing.
    private func beginTraceIfWatching() {
        guard var p = position, p.step == .watch else { return }
        p.step = .trace
        position = p
        if !review { journeys.setPosition(p) }
    }

    private func replayDemo() {
        if result == nil && guideKind != .memory {
            cancelPending()
            ink.clear()
        }
        startDemo()
    }

    private func startDemo() {
        guard let template = selected else { return }
        let start = Date()
        demoStart = start
        let total = StrokeDemoView.duration(for: template)
        DispatchQueue.main.asyncAfter(deadline: .now() + total + 0.8) {
            if demoStart == start {
                demoStart = nil
                beginTraceIfWatching()
            }
        }
    }

    /// Haptic tap for every score, confetti for great ones.
    private func react(to score: Int) {
        let haptics = UINotificationFeedbackGenerator()
        if score >= 85 {
            haptics.notificationOccurred(.success)
        } else if score >= 60 {
            haptics.notificationOccurred(.warning)
        } else {
            haptics.notificationOccurred(.error)
        }
    }

    private func goodMessage(_ score: Int) -> String {
        let name = lessonGlyph ?? selected?.glyph ?? "letter"
        if isLesson {
            return score >= 85 ? "Lovely \(name)! Ready for the next step." : "Good \(name). Try once more, or move on."
        }
        switch freeMode {
        case .learn: return score >= 85 ? "Well traced! Try it in Practice next." : "Good. Trace it once more to make it smooth."
        case .practice: return score >= 85 ? "Great control! Try it with less guide, or in Test." : "Nice. One more for consistency."
        case .test: return score >= 85 ? "Excellent, written from memory!" : "Good. Keep practising this one."
        }
    }
}
