import SwiftUI
import UIKit

/// What a worksheet is for: free practice of one letter in a mode, or a step
/// of a journey lesson.
enum WorksheetContext: Hashable {
    case free(WritingMode, String)
    case lesson(LessonPosition, review: Bool)
}

/// The worksheet: write a letter and it is scored automatically after a short
/// pause, with one specific correction. The page never moves when feedback
/// appears; the learner decides when to retry or move on.
struct WorksheetView: View {
    enum PracticeGuide: String, CaseIterable, Identifiable {
        case faint = "Faint model"
        case lines = "Lines only"
        var id: String { rawValue }
    }

    private enum GuideKind { case learn, faint, lines, memory }

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

    @StateObject private var ink = InkModel()
    @ObservedObject private var progress = ProgressStore.shared
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var journeys = JourneyStore.shared

    @State private var freeMode: WritingMode
    @State private var freeTemplateID: String
    @State private var position: LessonPosition?

    @State private var practiceGuide: PracticeGuide = .faint
    @State private var peek = false
    @State private var usedHint = false
    @State private var canvasSize: CGSize = .zero

    @State private var result: ScoreResult?
    @State private var currentAttempt: Attempt?
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
    @State private var celebrationStart: Date?
    @State private var showDetails = false

    private let library = TemplateLibrary.shared
    private let railWidth: CGFloat = 340
    private let portraitRailHeight: CGFloat = 220

    init(context: WorksheetContext, path: Binding<[Route]>) {
        _path = path
        switch context {
        case .free(let mode, let id):
            _freeMode = State(initialValue: mode)
            _freeTemplateID = State(initialValue: id)
            _position = State(initialValue: nil)
            review = false
        case .lesson(let p, let isReview):
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
        return freeTemplateID
    }

    private var selected: LetterTemplate? { library.template(id: templateID) }
    private var mode: WritingMode { position?.step.mode ?? freeMode }
    private var isLesson: Bool { position != nil }

    private var freeLetters: [LetterTemplate] {
        library.templates(style: selected?.style ?? settings.style.rawValue)
    }

    private var guideKind: GuideKind {
        if let step = position?.step { return step == .memory ? .memory : .learn }
        switch freeMode {
        case .learn: return .learn
        case .practice: return practiceGuide == .faint ? .faint : .lines
        case .test: return .memory
        }
    }

    private var title: String {
        if let p = position, let c = chapter, let g = lessonGlyph {
            return "\(c.title) · \(g) · \(p.step.title)"
        }
        return "\(mode.rawValue) · \(selected?.spokenName ?? "")"
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
        GeometryReader { outer in
            let landscape = outer.size.width > outer.size.height
            Group {
                if landscape {
                    HStack(spacing: 0) {
                        if settings.handedness == .right {
                            rail(landscape: true).frame(width: railWidth)
                            Divider()
                            page
                        } else {
                            page
                            Divider()
                            rail(landscape: true).frame(width: railWidth)
                        }
                    }
                } else {
                    VStack(spacing: 0) {
                        page
                        Divider()
                        rail(landscape: false).frame(height: portraitRailHeight)
                    }
                }
            }
            .onChange(of: outer.size) { _, _ in startOver() }
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
        .toolbar { toolbarContent }
        .onAppear(perform: appear)
        .onDisappear {
            cancelPending()
            commitIfNeeded()
        }
        .onChange(of: ink.revision) { _, _ in inkChanged() }
        .onChange(of: ink.isDrawing) { _, drawing in drawingChanged(drawing) }
        .onChange(of: peek) { _, isOn in if isOn { usedHint = true } }
        .onChange(of: ink.pencilOnly) { _, value in settings.pencilOnly = value }
        .onChange(of: settings.size) { _, _ in startOver() }
        .onChange(of: settings.handedness) { _, _ in startOver() }
    }

    // MARK: - Page

    private var page: some View {
        GeometryReader { geo in
            let layout = makeLayout(geo.size)
            ZStack(alignment: .topLeading) {
                Color.paper
                RuledLinesView(layout: layout, highlighted: highlightedLines)
                if let template = selected {
                    guide(for: template, layout: layout)
                    if result != nil, let previous = previousAttempt {
                        AttemptGhost(strokes: previous.strokes, layout: layout)
                    }
                    if let start = demoStart {
                        StrokeDemoView(template: template, layout: layout, start: start, color: mode.color)
                    }
                }
                InkCanvas(model: ink)
                if mode == .test, let template = selected {
                    TargetLetterCard(template: template, hinted: usedHint)
                        .padding(16)
                }
                if let start = celebrationStart {
                    ConfettiView(start: start)
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
                            pathOpacity: 0.22, solidPath: true, highlight: highlight)
        case .lines:
            TemplateOverlay(template: template, layout: layout, showPath: false, showArrows: false,
                            showDots: false, highlight: highlight)
        case .memory:
            TemplateOverlay(template: template, layout: layout, showPath: peek, showArrows: peek,
                            showDots: peek, highlight: highlight)
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
            if !isLesson {
                letterMenu
            }

            if guideKind != .memory || result != nil {
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
            if !isLesson {
                Picker("Mode", selection: freeModeBinding) {
                    ForEach(WritingMode.allCases) { Label($0.rawValue, systemImage: $0.symbol).tag($0) }
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
                freeMode = newMode
                practiceGuide = .faint
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
            case .trace: return "Trace the \(name) from the green dot, following the arrow."
            case .memory: return "Write the \(name) from memory."
            }
        }
        switch freeMode {
        case .learn: return "Trace the \(name) from the green dot, following the arrow."
        case .practice:
            return practiceGuide == .faint ? "Write over the faint letter." : "Now write it on the lines, with no model."
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
            if !isLesson && freeMode == .practice {
                Picker("Guide", selection: $practiceGuide) {
                    ForEach(PracticeGuide.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)
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
                Button { showDetails = true } label: {
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

    /// Try again leads when there is a correction; moving on leads otherwise.
    @ViewBuilder
    private var actions: some View {
        if let r = result {
            VStack(spacing: 10) {
                if r.tip != nil {
                    primaryButton("Try again", "arrow.counterclockwise", action: tryAgain)
                    secondaryButton(nextLabel, "arrow.right", action: goNext)
                } else {
                    primaryButton(nextLabel, "arrow.right", action: goNext)
                    secondaryButton("Try again", "arrow.counterclockwise", action: tryAgain)
                }
                if !isLesson && freeMode == .practice && practiceGuide == .faint {
                    secondaryButton("Try with less guide", "eye.slash") {
                        practiceGuide = .lines
                        tryAgain()
                    }
                }
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
        guard let p = position, let j = journey else { return "Next letter" }
        let next = journeys.next(after: p, in: j)
        if review {
            if let next, next.chapterID == p.chapterID, next.letterIndex == p.letterIndex {
                return "Next step: \(next.step.title)"
            }
            return "Back to map"
        }
        guard let next else { return "See recap" }
        if next.chapterID != p.chapterID { return "Finish chapter" }
        if next.letterIndex != p.letterIndex { return "Next letter" }
        return "Next step: \(next.step.title)"
    }

    // MARK: - Automatic scoring

    private func inkChanged() {
        cancelPending()
        if result != nil {
            result = nil // the ink changed, so the old feedback is stale
            celebrationStart = nil
        }
        guard ink.strokeCount > 0 else { return }
        if !ink.isDrawing { schedule() }
    }

    private func drawingChanged(_ drawing: Bool) {
        if drawing {
            cancelPending()
            result = nil
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
        let delay = expectsMoreStrokes ? WorksheetView.finishingPause : WorksheetView.pause
        checking = true
        let work = DispatchWorkItem { scoreNow(revision: revision, token: token) }
        pendingScore = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func cancelPending() {
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
        } catch {
            errorText = "Could not score this letter: \(error.localizedDescription)"
        }
    }

    /// Saves the latest scored version of this attempt to progress, once.
    private func commitIfNeeded() {
        guard let attempt = currentAttempt, !committed else { return }
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
        celebrationStart = nil
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
        peek = false
        usedHint = false
        startOver()
    }

    private func goNext() {
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
        freeTemplateID = id
        practiceGuide = .faint
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
            replaceRoute(with: review ? .journeyMap(j.id) : .recap(j.id))
            return
        }
        if review && (next.chapterID != p.chapterID || next.letterIndex != p.letterIndex) {
            if !path.isEmpty { path.removeLast() } // back to the map; the journey place is unchanged
            return
        }
        if next.chapterID != p.chapterID, let nextChapter = j.chapter(next.chapterID) {
            journeys.lockCheckpointPicks(nextChapter, in: j)
            notice = "\(chapter?.title ?? "Chapter") complete. Next: \(nextChapter.title)"
        }
        if !review { journeys.setPosition(next) }
        position = next
        practiceGuide = .faint
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
            let start = Date()
            celebrationStart = start
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                if celebrationStart == start { celebrationStart = nil }
            }
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
