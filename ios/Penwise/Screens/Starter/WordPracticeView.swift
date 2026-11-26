import SwiftUI

/// STARTER SCREEN (to be redesigned): practice words one after another.
struct WordPracticeView: View {
    @StateObject private var session: WordSession
    @StateObject private var ink = InkModel()
    @State private var size: CGSize = .zero

    init(request: WordRequest) {
        _session = StateObject(wrappedValue: WordSession(request: request))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ProgressView(value: session.progress)
            if session.isFinished {
                Text("Words done!").font(.workbook(.largeTitle))
                Text("Average \(session.average) · Best \(session.best)")
            } else if session.words.isEmpty {
                Text("No words found for these letters.")
            } else if let word = session.word {
                Text(session.traced ? "Trace: \(word)" : "Write: \(word)").font(.workbook(.title))
                GeometryReader { geo in
                    let layout = session.layout(in: geo.size)
                    ZStack {
                        RuledLinesView(layout: layout, highlighted: highlighted)
                        if session.traced, let plan = session.plan {
                            ForEach(plan.templates.indices, id: \.self) { i in
                                TemplateOverlay(template: plan.templates[i],
                                                layout: GuideLayout(origin: CGPoint(x: layout.origin.x + plan.xs[i] * layout.unit,
                                                                                    y: layout.origin.y), unit: layout.unit),
                                                showArrows: i == 0, showDots: i == 0, pathOpacity: 0.22, solidPath: true)
                            }
                        }
                        InkCanvas(model: ink)
                    }
                    .onAppear { size = geo.size }
                    .onChange(of: geo.size) { _, s in size = s; ink.clear() }
                }
                .background(Color.paper, in: RoundedRectangle(cornerRadius: 18))
                if let result = session.lastResult {
                    HStack(spacing: 12) {
                        Text("\(result.overall)").font(.title.bold()).foregroundStyle(scoreColor(result.overall))
                        Text(result.tip ?? "Lovely word!").font(.workbook(.title3))
                        Spacer()
                        Button("Again") { session.retry(); ink.clear() }
                        Button("Next") { session.next(); ink.clear() }.buttonStyle(.borderedProminent)
                    }
                } else {
                    HStack {
                        Button("Check") {
                            session.submit(strokes: ink.capturedStrokes(in: session.layout(in: size)),
                                           finger: ink.lastInkUsedFinger)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(ink.strokeCount == 0 || ink.isDrawing)
                        Button("Clear") { ink.clear() }
                    }
                }
            }
        }
        .padding(28)
        .background(Color.paperCard)
        .navigationTitle("Words")
    }

    private var highlighted: [CGFloat] {
        switch session.request.focus {
        case "BASELINE": return [1.0]
        case "SIZE": return [0.5]
        default: return []
        }
    }
}
