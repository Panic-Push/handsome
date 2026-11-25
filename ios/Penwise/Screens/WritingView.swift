import SwiftUI
import UIKit

/// Write a letter in Learn, Practice or Test mode and get it scored.
struct WritingView: View {
    @StateObject private var ink = InkModel()
    @ObservedObject private var progress = ProgressStore.shared

    @State private var mode: WritingMode
    @State private var selectedID: String
    @State private var peek = false
    @State private var canvasSize: CGSize = .zero
    @State private var result: ScoreResult?
    @State private var errorText: String?
    @State private var demoStart: Date?
    @State private var celebrationStart: Date?

    private let library = TemplateLibrary.shared

    init(mode: WritingMode, templateID: String) {
        _mode = State(initialValue: mode)
        _selectedID = State(initialValue: templateID)
    }

    private var selected: LetterTemplate? { library.template(id: selectedID) }
    private var letterWidth: CGFloat { CGFloat(selected?.width ?? 0.5) }
    private var layout: GuideLayout { GuideLayout.fit(in: canvasSize, letterWidth: letterWidth) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            GeometryReader { geo in
                let layout = GuideLayout.fit(in: geo.size, letterWidth: letterWidth)
                ZStack {
                    Color(uiColor: .systemBackground)
                    RuledLinesView(layout: layout)
                    if let template = selected {
                        guide(for: template, layout: layout)
                        if let start = demoStart {
                            StrokeDemoView(template: template, layout: layout, start: start, color: mode.color)
                        }
                    }
                    InkCanvas(model: ink)
                    if let start = celebrationStart {
                        ConfettiView(start: start)
                    }
                }
                .onAppear { canvasSize = geo.size }
                .onChange(of: geo.size) { _, newSize in
                    canvasSize = newSize
                    ink.clear() // the guides moved, so old ink would no longer line up
                }
            }
            Divider()
            bottomPanel
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: result?.overall)
        }
        .navigationTitle("\(mode.rawValue) · \(selected?.glyph ?? "")")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .onAppear {
            if mode == .learn { startDemo() }
        }
        .onChange(of: ink.strokeCount) { _, count in
            result = nil // new ink makes the old score stale
            if count > 0 { demoStart = nil }
        }
        .onChange(of: mode) { _, newMode in
            peek = false
            result = nil
            ink.clear()
            if newMode == .learn { startDemo() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(library.templates) { template in
                        let isSelected = template.id == selectedID
                        Button {
                            select(template.id)
                        } label: {
                            VStack(spacing: 3) {
                                Text(template.glyph)
                                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.primary)
                                StarsView(count: ProgressStore.stars(for: progress.best(mode, template.id)), size: 8, spacing: 1)
                            }
                            .frame(width: 58, height: 62)
                            .background(isSelected ? mode.color.opacity(0.15) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(isSelected ? mode.color : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 2)
            }

            Picker("Mode", selection: $mode) {
                ForEach(WritingMode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 300)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Guide per mode

    @ViewBuilder
    private func guide(for template: LetterTemplate, layout: GuideLayout) -> some View {
        let highlight = result?.problemStrokes ?? []
        switch mode {
        case .learn:
            TemplateOverlay(template: template, layout: layout, highlight: highlight)
        case .practice:
            TemplateOverlay(template: template, layout: layout, showArrows: false, pathOpacity: 0.22, highlight: highlight)
        case .test:
            TemplateOverlay(template: template, layout: layout, showPath: peek, showArrows: peek, showDots: peek, highlight: highlight)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if mode == .test {
                Toggle(isOn: $peek) {
                    Label("Peek", systemImage: peek ? "eye" : "eye.slash")
                }
                .toggleStyle(.button)
            }

            Toggle(isOn: $ink.pencilOnly) {
                Label(ink.pencilOnly ? "Pencil only" : "Pencil and finger",
                      systemImage: ink.pencilOnly ? "applepencil" : "hand.draw")
            }
            .toggleStyle(.button)

            Button { ink.undo() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                .disabled(ink.strokeCount == 0)
            Button { ink.redo() } label: { Label("Redo", systemImage: "arrow.uturn.forward") }
                .disabled(!ink.canRedo)
            Button(role: .destructive) { tryAgain() } label: { Label("Clear", systemImage: "trash") }
                .disabled(ink.strokeCount == 0)
        }
    }

    // MARK: - Bottom panel

    @ViewBuilder
    private var bottomPanel: some View {
        if let result = result {
            resultPanel(result)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            promptPanel
                .transition(.opacity)
        }
    }

    private var promptPanel: some View {
        HStack(spacing: 16) {
            Image(systemName: mode.symbol)
                .font(.title)
                .foregroundStyle(mode.color)
                .frame(width: 54, height: 54)
                .background(mode.color.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 6) {
                Text(errorText ?? mode.instruction)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(errorText == nil ? Color.primary : Color.red)
                    .fixedSize(horizontal: false, vertical: true)
                statsLine
            }
            Spacer(minLength: 0)
            if mode != .test {
                Button {
                    ink.clear()
                    startDemo()
                } label: {
                    Label("Watch", systemImage: "play.circle")
                }
                .buttonStyle(.bordered)
                .tint(mode.color)
                .controlSize(.large)
            }
            Button(action: check) {
                Label("Check", systemImage: "checkmark.circle.fill")
                    .frame(minWidth: 110)
            }
            .buttonStyle(.borderedProminent)
            .tint(mode.color)
            .controlSize(.large)
            .disabled(ink.strokeCount == 0)
        }
        .padding(16)
        .frame(minHeight: 132)
    }

    private func resultPanel(_ r: ScoreResult) -> some View {
        let entry = progress.entry(mode, selectedID)
        return HStack(alignment: .center, spacing: 20) {
            ScoreRing(score: r.overall)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    StarsView(count: ProgressStore.stars(for: r.overall), size: 22, animated: true)
                    if let entry = entry {
                        Text(entry.best > r.overall ? "Best \(entry.best) · attempt \(entry.attempts)"
                                                    : "New best! · attempt \(entry.attempts)")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(r.tip ?? goodMessage(r.overall))
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(r.parts) { PartChip(part: $0) }
                    }
                }
            }
            Spacer(minLength: 0)
            VStack(spacing: 10) {
                Button(action: next) {
                    Label("Next letter", systemImage: "arrow.right")
                        .frame(minWidth: 150)
                }
                .buttonStyle(.borderedProminent)
                .tint(mode.color)
                .controlSize(.large)
                Button(action: tryAgain) {
                    Label("Try again", systemImage: "arrow.counterclockwise")
                        .frame(minWidth: 150)
                }
                .buttonStyle(.bordered)
                .tint(mode.color)
                .controlSize(.large)
            }
        }
        .padding(16)
        .frame(minHeight: 132)
        .background(mode.color.opacity(0.06))
    }

    private var statsLine: some View {
        let _ = ink.revision // refresh after every stroke
        let stats = ink.stats(in: layout)
        return HStack(spacing: 16) {
            Text("Strokes \(stats.strokes)")
            if let p = stats.averagePressure {
                Text("Pressure \(p, specifier: "%.2f")")
            }
            if stats.strokes > 0 {
                Text(stats.usedFinger ? "Finger" : "Pencil")
                Text("\(stats.seconds, specifier: "%.1f") s")
            }
        }
        .font(.callout.monospacedDigit())
        .foregroundStyle(.secondary)
    }

    // MARK: - Actions

    private func select(_ id: String) {
        guard id != selectedID else { return }
        selectedID = id
        result = nil
        ink.clear()
        if mode == .learn { startDemo() }
    }

    private func next() {
        let all = library.templates
        guard let i = all.firstIndex(where: { $0.id == selectedID }), !all.isEmpty else { return }
        select(all[(i + 1) % all.count].id)
    }

    private func tryAgain() {
        result = nil
        ink.clear()
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

    private func check() {
        guard let template = selected, let json = library.json(for: template.id) else {
            errorText = "This letter's template is missing."
            return
        }
        do {
            let score = try CoreBridge.score(
                strokes: ink.capturedStrokes(in: layout),
                templateID: template.id,
                templateJSON: json,
                mode: mode,
                finger: ink.lastInkUsedFinger
            )
            errorText = nil
            progress.record(score: score.overall, mode: mode, templateID: template.id)
            result = score
            react(to: score.overall)
        } catch {
            errorText = "Could not score this letter: \(error.localizedDescription)"
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
        case .learn: return score >= 85 ? "Well traced! Try it in Practice next." : "Good. Trace it once more."
        case .practice: return score >= 85 ? "Great control! Try it in Test mode." : "Nice. One more for consistency."
        case .test: return score >= 85 ? "Excellent, written from memory!" : "Good. Keep practising this one."
        }
    }
}
