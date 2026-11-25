import SwiftUI

/// Milestone 1: trace a letter over its dotted guide on ruled lines.
/// Scoring is added in Milestone 3, once the shared engine is linked in.
struct TracingView: View {
    @StateObject private var ink = InkModel()
    @State private var selected: LetterTemplate?
    @State private var showGuide = true
    @State private var canvasSize: CGSize = .zero

    private let templates = TemplateLibrary.shared.templates

    private var layout: GuideLayout {
        GuideLayout.fit(in: canvasSize, letterWidth: CGFloat(selected?.width ?? 0.5))
    }

    var body: some View {
        VStack(spacing: 0) {
            letterBar
            Divider()
            GeometryReader { geo in
                let layout = GuideLayout.fit(in: geo.size, letterWidth: CGFloat(selected?.width ?? 0.5))
                ZStack {
                    Color(uiColor: .systemBackground)
                    RuledLinesView(layout: layout)
                    if showGuide, let template = selected {
                        TemplateOverlay(template: template, layout: layout)
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
            statsBar
        }
        .navigationTitle("Trace")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Toggle(isOn: $showGuide) {
                    Label("Guide", systemImage: showGuide ? "eye" : "eye.slash")
                }
                .toggleStyle(.button)

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
        .onAppear {
            if selected == nil {
                selected = templates.first { $0.glyph == "c" } ?? templates.first
            }
        }
    }

    private var letterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if templates.isEmpty {
                    Text("No letter templates found in the app bundle.")
                        .foregroundStyle(.secondary)
                }
                ForEach(templates) { template in
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
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var statsBar: some View {
        // Reading `revision` makes this refresh after every stroke.
        let _ = ink.revision
        let stats = ink.stats(in: layout)
        return HStack(spacing: 20) {
            Text("Strokes \(stats.strokes)")
            Text("Points \(stats.points)")
            if let p = stats.averagePressure {
                Text("Avg pressure \(p, specifier: "%.2f")")
            }
            if stats.strokes > 0 {
                Text(stats.usedFinger ? "Finger" : "Pencil")
                Text("Time \(stats.seconds, specifier: "%.1f") s")
            }
            Spacer()
            Text("Scoring arrives in Milestone 3")
                .foregroundStyle(.secondary)
        }
        .font(.callout.monospacedDigit())
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
