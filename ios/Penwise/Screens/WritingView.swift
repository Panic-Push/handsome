import SwiftUI
import UIKit

/// The worksheet: write a letter, see one specific correction, try again.
///
/// The page never moves: feedback appears in a fixed-height bar below it, so
/// the ink stays where it was written and can be compared with the tip.
struct WritingView: View {
    enum PracticeGuide: String, CaseIterable, Identifiable {
        case faint = "Faint model"
        case lines = "Lines only"
        var id: String { rawValue }
    }

    struct Attempt {
        let strokes: [CapturedStroke]
        let result: ScoreResult
    }

    @StateObject private var ink = InkModel()
    @ObservedObject private var progress = ProgressStore.shared
    @ObservedObject private var settings = AppSettings.shared

    @State private var mode: WritingMode
    @State private var selectedID: String
    @State private var practiceGuide: PracticeGuide = .faint
    @State private var peek = false
    @State private var usedHint = false
    @State private var canvasSize: CGSize = .zero
    @State private var result: ScoreResult?
    @State private var lastAttempt: Attempt?
    @State private var previousAttempt: Attempt?
    @State private var comparison: Comparison?
    @State private var errorText: String?
    @State private var demoStart: Date?
    @State private var celebrationStart: Date?
    @State private var showDetails = false

    private let library = TemplateLibrary.shared
    private let barHeight: CGFloat = 196

    init(mode: WritingMode, templateID: String) {
        _mode = State(initialValue: mode)
        _selectedID = State(initialValue: templateID)
    }

    private var selected: LetterTemplate? { library.template(id: selectedID) }

    /// Letters in the same style as the current one, in teaching order.
    private var letters: [LetterTemplate] {
        library.templates(style: selected?.style ?? settings.style.rawValue)
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
        VStack(spacing: 0) {
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
            Divider()
            bottomBar
                .frame(height: barHeight)
                .background(Color.paperCard)
        }
        .navigationTitle("\(mode.rawValue) · \(selected?.spokenName ?? "")")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .onAppear {
            ink.pencilOnly = settings.pencilOnly
            if mode == .learn { startDemo() }
        }
        .onChange(of: ink.strokeCount) { _, count in
            if count > 0 { demoStart = nil }
            if count == 0 { usedHint = peek }
            result = nil // new ink makes the old score stale
        }
        .onChange(of: peek) { _, isOn in
            if isOn { usedHint = true }
        }
        .onChange(of: ink.pencilOnly) { _, value in settings.pencilOnly = value }
        .onChange(of: mode) { _, newMode in
            practiceGuide = .faint
            resetLetter()
            if newMode == .learn { startDemo() }
        }
        .onChange(of: settings.size) { _, _ in startOver() }
        .onChange(of: settings.handedness) { _, _ in startOver() }
    }

    // MARK: - Guide per mode

    @ViewBuilder
    private func guide(for template: LetterTemplate, layout: GuideLayout) -> some View {
        let highlight = result?.problemStrokes ?? []
        switch mode {
        case .learn:
            TemplateOverlay(template: template, layout: layout, highlight: highlight)
        case .practice:
            if practiceGuide == .faint {
                TemplateOverlay(template: template, layout: layout, showArrows: false, showDots: false,
                                pathOpacity: 0.22, solidPath: true, highlight: highlight)
            } else {
                TemplateOverlay(template: template, layout: layout, showPath: false, showArrows: false,
                                showDots: false, highlight: highlight)
            }
        case .test:
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
            letterMenu

            if mode != .test || result != nil {
                Button { replayDemo() } label: {
                    Label(mode == .test ? "Replay" : "Watch again", systemImage: "play.circle")
                }
            }

            if mode == .test {
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
            ForEach(letters) { template in
                Button { select(template.id) } label: {
                    if template.id == selectedID {
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
            Picker("Mode", selection: $mode) {
                ForEach(WritingMode.allCases) { Label($0.rawValue, systemImage: $0.symbol).tag($0) }
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

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(alignment: .center, spacing: 24) {
            Group {
                if let result = result {
                    feedback(result)
                } else {
                    prompt
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            actions
                .frame(width: 220)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var instruction: String {
        if let errorText { return errorText }
        switch mode {
        case .learn: return WritingMode.learn.instruction
        case .practice:
            return practiceGuide == .faint ? "Write over the faint letter." : "Now write it on the lines, with no model."
        case .test:
            return "Write the \(selected?.spokenName ?? "letter") from memory."
        }
    }

    private var prompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(instruction)
                .font(.workbook(.title2))
                .foregroundStyle(errorText == nil ? Color.ink : Color.red)
                .fixedSize(horizontal: false, vertical: true)
            if mode == .practice {
                Picker("Guide", selection: $practiceGuide) {
                    ForEach(PracticeGuide.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
            }
            if mode == .test && usedHint {
                Text("You peeked, so this try will be saved as With hint.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func feedback(_ r: ScoreResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(r.tip == nil ? "Looks great" : "One thing to work on",
                  systemImage: r.tip == nil ? "checkmark.seal.fill" : "lightbulb.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(r.tip == nil ? Color.green : mode.color)
            Text(r.tip ?? goodMessage(r.overall))
                .font(.workbook(.title2))
                .foregroundStyle(Color.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
            if let comparison {
                Label(comparison.text, systemImage: comparison.improved ? "arrow.up.right.circle.fill" : "equal.circle")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(comparison.improved ? Color.green : Color.secondary)
                    .lineLimit(1)
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
                    ScoreDetailsView(result: r, history: progress.recentAttempts(mode, selectedID))
                }
                if mode == .test && usedHint {
                    Text("With hint")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.2), in: Capsule())
                }
            }
        }
    }

    /// Check and Try again share the top position, so the main button never moves.
    private var actions: some View {
        VStack(spacing: 10) {
            if result == nil {
                Button(action: check) {
                    Label("Check", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(mode.color)
                .controlSize(.large)
                .disabled(ink.strokeCount == 0)
                Spacer(minLength: 0)
            } else {
                Button(action: tryAgain) {
                    Label("Try again", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(mode.color)
                .controlSize(.large)
                if mode == .practice && practiceGuide == .faint {
                    Button {
                        practiceGuide = .lines
                        tryAgain()
                    } label: {
                        Label("Try with less guide", systemImage: "eye.slash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(mode.color)
                }
                Button(action: next) {
                    Label("Next letter", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(mode.color)
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Actions

    private func check() {
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
            progress.record(score: score.overall, mode: mode, templateID: template.id, hinted: mode == .test && usedHint)
            if let last = lastAttempt {
                previousAttempt = last
                comparison = Comparison.make(previous: last.result, current: score, glyph: template.glyph)
            } else {
                previousAttempt = nil
                comparison = nil
            }
            lastAttempt = Attempt(strokes: strokes, result: score)
            result = score
            react(to: score.overall)
        } catch {
            errorText = "Could not score this letter: \(error.localizedDescription)"
        }
    }

    /// Clears the page for another try at the same letter, keeping the last
    /// attempt so the next result can be compared with it.
    private func tryAgain() {
        result = nil
        demoStart = nil
        ink.clear()
    }

    /// Clears the page and forgets the last attempt (layout changed).
    private func startOver() {
        result = nil
        lastAttempt = nil
        previousAttempt = nil
        comparison = nil
        ink.clear()
    }

    /// A new letter or mode: start fresh.
    private func resetLetter() {
        peek = false
        usedHint = false
        startOver()
    }

    private func select(_ id: String) {
        guard id != selectedID else { return }
        selectedID = id
        practiceGuide = .faint
        resetLetter()
        if mode == .learn { startDemo() }
    }

    private func next() {
        let all = letters
        guard !all.isEmpty, let i = all.firstIndex(where: { $0.id == selectedID }) else { return }
        select(all[(i + 1) % all.count].id)
    }

    private func replayDemo() {
        if result == nil { ink.clear() }
        startDemo()
    }

    private func startDemo() {
        guard let template = selected else { return }
        let start = Date()
        demoStart = start
        let total = StrokeDemoView.duration(for: template)
        DispatchQueue.main.asyncAfter(deadline: .now() + total + 0.8) {
            if demoStart == start { demoStart = nil }
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
        switch mode {
        case .learn: return score >= 85 ? "Well traced! Try it in Practice next." : "Good. Trace it once more to make it smooth."
        case .practice: return score >= 85 ? "Great control! Try it with less guide, or in Test." : "Nice. One more for consistency."
        case .test: return score >= 85 ? "Excellent, written from memory!" : "Good. Keep practising this one."
        }
    }
}
