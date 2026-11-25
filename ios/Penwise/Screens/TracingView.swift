import SwiftUI

/// Write a letter in Learn, Practice or Test mode and get it scored by the
/// shared engine. The stroke that needs work is highlighted in red.
struct TracingView: View {
    @StateObject private var ink = InkModel()
    @State private var selected: LetterTemplate?
    @State private var mode: WritingMode = .learn
    @State private var peek = false
    @State private var canvasSize: CGSize = .zero
    @State private var result: ScoreResult?
    @State private var errorText: String?

    private let library = TemplateLibrary.shared

    private var layout: GuideLayout {
        GuideLayout.fit(in: canvasSize, letterWidth: CGFloat(selected?.width ?? 0.5))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            GeometryReader { geo in
                let layout = GuideLayout.fit(in: geo.size, letterWidth: CGFloat(selected?.width ?? 0.5))
                ZStack {
                    Color(uiColor: .systemBackground)
                    RuledLinesView(layout: layout)
                    if let template = selected {
                        guide(for: template, layout: layout)
                    }
                    InkCanvas(model: ink)
                }
                .onAppear { canvasSize = geo.size }
                .onChange(of: geo.size) { _, newSize in
                    canvasSize = newSize
                    ink.clear() // the guides moved, so old ink would no longer line up
                }
            }
            Divider()
            bottomPanel
        }
        .navigationTitle("Write")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .onAppear {
            if selected == nil {
                selected = library.templates.first { $0.glyph == "c" } ?? library.templates.first
            }
        }
        .onChange(of: ink.strokeCount) { _, _ in
            result = nil // any new ink makes the old score stale
        }
        .onChange(of: mode) { _, _ in
            peek = false
            ink.clear()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if library.templates.isEmpty {
                        Text("No letter templates found in the app bundle.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(library.templates) { template in
                        Button {
                            selected = template
                            ink.clear()
                        } label: {
                            Text(template.glyph)
                                .font(.system(size: 30, weight: .semibold, design: .rounded))
                                .frame(width: 56, height: 56)
                                .background(
                                    selected == template ? Color.accentColor.opacity(0.18) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 12)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
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
            Button(role: .destructive) { ink.clear() } label: { Label("Clear", systemImage: "trash") }
                .disabled(ink.strokeCount == 0)
        }
    }

    // MARK: - Bottom panel

    private var bottomPanel: some View {
        HStack(alignment: .center, spacing: 20) {
            if let result = result {
                ScoreBadge(score: result.overall)
                VStack(alignment: .leading, spacing: 10) {
                    Text(result.tip ?? goodMessage(result.overall))
                        .font(.title3.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(result.parts) { PartChip(part: $0) }
                        }
                    }
                }
                Spacer(minLength: 0)
                Button {
                    ink.clear()
                } label: {
                    Label("Try again", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(errorText ?? mode.instruction)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(errorText == nil ? Color.primary : Color.red)
                    statsLine
                }
                Spacer(minLength: 0)
                Button(action: check) {
                    Label("Check", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(ink.strokeCount == 0)
            }
        }
        .padding(16)
        .frame(minHeight: 116)
    }

    private var statsLine: some View {
        let _ = ink.revision // refresh after every stroke
        let stats = ink.stats(in: layout)
        return HStack(spacing: 16) {
            Text("Strokes \(stats.strokes)")
            Text("Points \(stats.points)")
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

    private func goodMessage(_ score: Int) -> String {
        switch mode {
        case .learn: return score >= 85 ? "Well traced! Try it in Practice next." : "Good. Trace it once more."
        case .practice: return score >= 85 ? "Great control! Try it in Test mode." : "Nice. One more for consistency."
        case .test: return score >= 85 ? "Excellent, written from memory!" : "Good. Keep practising this one."
        }
    }

    private func check() {
        guard let template = selected, let json = library.json(for: template.id) else {
            errorText = "This letter's template is missing."
            return
        }
        do {
            result = try CoreBridge.score(
                strokes: ink.capturedStrokes(in: layout),
                templateID: template.id,
                templateJSON: json,
                mode: mode,
                finger: ink.lastInkUsedFinger
            )
            errorText = nil
        } catch {
            errorText = "Could not score this letter: \(error.localizedDescription)"
        }
    }
}

private struct ScoreBadge: View {
    let score: Int

    private var color: Color {
        if score >= 85 { return .green }
        if score >= 60 { return .orange }
        return .red
    }

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.2), lineWidth: 8)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(score)")
                .font(.system(size: 30, weight: .bold, design: .rounded))
        }
        .frame(width: 80, height: 80)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score \(score) out of 100")
    }
}

private struct PartChip: View {
    let part: ScorePart

    var body: some View {
        Text("\(part.name) \(part.value)")
            .font(.callout.monospacedDigit())
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.12), in: Capsule())
    }
}
