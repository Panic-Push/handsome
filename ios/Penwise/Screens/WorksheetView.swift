import SwiftUI
import UIKit
import Lottie

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
    @State private var run = LetterRun()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            _run = State(initialValue: p.worksheet ?? LetterRun())
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
        if position?.step == .memory { return .memory }
        if position != nil || freeMode == .learn {
            return run.scores.count % 3 == 2 ? .faint : .learn
        }
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
                            worksheetGrid
                        } else {
                            worksheetGrid
                            Divider()
                            rail(landscape: true).frame(width: railWidth)
                        }
                    }
                } else {
                    VStack(spacing: 0) {
                        worksheetGrid
                        Divider()
                        rail(landscape: false).frame(height: portraitRailHeight)
                    }
                }
            }
            .allowsHitTesting(result == nil && !run.complete)
            .accessibilityHidden(result != nil || run.complete)
            .overlay {
                if run.complete || result != nil { resultScreen }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { if result == nil && !run.complete { toolbarContent } }
        .toolbar(result != nil || run.complete ? .hidden : .visible, for: .navigationBar)
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

    private var worksheetGrid: some View {
        VStack(spacing: 8) {
            ForEach(0..<2) { row in
                HStack(spacing: 4) {
                    ForEach(0..<3) { column in
                        let index = row * 3 + column
                        if index == run.scores.count {
                            page
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(mode.color, lineWidth: 2))
                        } else {
                            GeometryReader { geo in
                                let layout = makeLayout(geo.size)
                                ZStack {
                                    RuledLinesView(layout: layout)
                                    if let template = selected, guideKind == .learn || guideKind == .faint {
                                        TemplateOverlay(template: template, layout: layout, showArrows: false,
                                                        showDots: false, pathOpacity: 0.18, solidPath: true)
                                    }
                                }
                                .overlay(alignment: .topLeading) {
                                    if index < run.scores.count {
                                        Label("\(run.scores[index])", systemImage: "checkmark.circle.fill")
                                            .font(.caption.bold()).foregroundStyle(.green).padding(8)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
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
                    if result != nil, let previous = previousAttempt {
                        AttemptGhost(strokes: previous.strokes, layout: layout)
                    }
                    if let start = demoStart {
                        StrokeDemoView(template: template, layout: layout, start: start, color: mode.color)
                    }
                }
                InkCanvas(model: ink)

            }
            .onAppear { canvasSize = geo.size }
            .onChange(of: geo.size) { _, newSize in
                canvasSize = newSize
                if result == nil { startOver() }
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
                    prompt
                    Spacer(minLength: 0)
                }
                .padding(24)
            } else {
                HStack(alignment: .center, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        if isLesson { stepChips }
                        prompt
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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

    private var instruction: String {
        if let errorText { return errorText }
        let name = lessonGlyph ?? selected?.glyph ?? "letter"
        if let step = position?.step {
            switch step {
            case .watch: return "Watch how the \(name) is written. Start tracing whenever you're ready."
            case .trace where guideKind == .faint: return "Trace the faint \(name) on the lines."
            case .trace: return "Trace the \(name) from the green dot, following the arrow."
            case .memory: return "Write the \(name) from memory."
            }
        }
        switch freeMode {
        case .learn where guideKind == .faint: return "Trace the faint \(name) on the lines."
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
            Text("Exercise \(min(run.scores.count + 1, LetterRun.count)) of \(LetterRun.count)")
                .font(.headline)
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

    private var passed: Bool {
        guard let attempt = currentAttempt else { return false }
        return attempt.result.overall >= ProgressStore.passMark && !attempt.hinted
    }

    private var resultScreen: some View {
        let summary = run.complete
        let success = summary || passed
        let fox = LottieView(animation: .asset(success ? "fox_celebrate" : "fox_encourage")).resizable()
        return ScrollView {
            VStack(spacing: 12) {
                Group {
                    if reduceMotion { fox } else { fox.looping() }
                }
                .frame(width: 160, height: 160)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                Text(summary ? "Letter complete · \(selected?.glyph ?? "")" :
                        (success ? "Exercise passed!" : "Give it another try"))
                    .font(.workbook(.title))
                if summary {
                    StarsView(count: ProgressStore.stars(for: run.average), size: 32, animated: true)
                    Text("Average \(run.average)/100 · Best \(run.best)/100")
                    Text("\(run.scores.count) exercises · \(run.attempts) attempts")
                    ForEach(run.scores.indices, id: \.self) { i in
                        Text("Exercise \(i + 1) · \(run.scores[i])/100")
                    }
                } else if let result {
                    ScoreRing(score: result.overall)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 128))]) {
                        ForEach(result.parts) { PartChip(part: $0) }
                    }
                    if let tip = result.tip { Text(tip) }
                    if let comparison, comparison.improved { Text(comparison.text) }
                    if currentAttempt?.hinted == true {
                        Text("Try once more without peeking to pass.")
                    }
                }
                Text(summary ? summaryAction : (success ?
                    (run.scores.count == LetterRun.count - 1 ? "Tap for letter stats" : "Tap for the next exercise") :
                    "Tap to retry this exercise"))
                    .font(.headline).foregroundStyle(mode.color)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: 540)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(Color.paperCard)
        .contentShape(Rectangle())
        .onTapGesture(perform: continueResult)
        .accessibilityAction(named: Text("Continue")) { continueResult() }
    }

    private var summaryAction: String {
        if let p = position, let j = journey, journeys.next(after: p, in: j) == nil {
            return review ? "Tap to return to the map" : "Tap for the journey recap"
        }
        return "Tap for the next letter"
    }

    private func saveRun() {
        guard var p = position else { return }
        p.worksheet = run
        position = p
        if !review { journeys.setPosition(p) }
    }

    private func continueResult() {
        if run.complete {
            goNext()
            return
        }
        guard let score = result else { return }
        let advance = passed
        tryAgain()
        peek = false
        usedHint = false
        guard advance else { return }
        previousAttempt = nil
        run.scores.append(score.overall)
        if run.scores.count == 3, var p = position, p.step == .trace {
            if let glyph = lessonGlyph { journeys.markComplete(p, glyph: glyph) }
            p.step = .memory
            position = p
        }
        saveRun()
    }

    // MARK: - Automatic scoring

    private func inkChanged() {
        cancelPending()
        guard result == nil, !run.complete else { return }
        guard ink.strokeCount > 0 else { return }
        if !ink.isDrawing { schedule() }
    }

    private func drawingChanged(_ drawing: Bool) {
        guard result == nil, !run.complete else { return }
        if drawing {
            cancelPending()
            result = nil
            demoStart = nil
            notice = nil
            if peek { usedHint = true }
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
        guard result == nil, !run.complete, token == exercise, revision == ink.revision,
              !ink.isDrawing, ink.strokeCount > 0 else { return }
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
            run.record(score.overall)
            commitIfNeeded()
            saveRun()
            UINotificationFeedbackGenerator().notificationOccurred(passed ? .success : .warning)
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
        run = LetterRun()
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
}
