import PencilKit
import SwiftUI

/// All letters for one mode in the chosen style, with stars and best scores.
struct LetterPickerView: View {
    let mode: WritingMode

    @ObservedObject private var progress = ProgressStore.shared
    @ObservedObject private var settings = AppSettings.shared
    private let library = TemplateLibrary.shared

    private var letters: [LetterTemplate] { library.templates(style: settings.style) }

    /// The first letter not yet passed in this mode.
    private var upNext: LetterTemplate? {
        letters.first { (progress.best(mode, $0.id) ?? 0) < ProgressStore.passMark }
    }

    @ViewBuilder
    private func activities(_ course: Journey) -> some View {
        let chapters = course.chapters.filter { !$0.isCheckpoint }
        VStack(alignment: .leading, spacing: 12) {
            Text(mode == .test ? "Memory tests" : "Chapter drills").font(.workbook(.title2))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 215), spacing: 12)], spacing: 12) {
                ForEach(chapters) { chapter in
                    activity(chapter.title, glyphs: chapter.letters, course: course)
                }
                if mode == .test {
                    activity("Full alphabet", glyphs: chapters.flatMap(\.letters), course: course)
                }
            }
        }
    }

    private func activity(_ title: String, glyphs: [String], course: Journey) -> some View {
        NavigationLink(value: Route.set(mode, title, glyphs.map { course.templateID($0) }, shuffled: mode == .test)) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: mode.symbol).foregroundStyle(mode.color)
                Text(title).font(.headline)
                Text("\(glyphs.count) letters" + (mode == .test ? " · shuffled" : " · guided"))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .paperCard(radius: 16)
        }
        .buttonStyle(PressableStyle())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 18) {
                    Image(systemName: mode.symbol)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(mode.color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(settings.style.title) · \(mode.rawValue)")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ink)
                        Text(mode.subtitle)
                            .font(.workbook(.title3, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                NavigationLink(value: Route.sentences(settings.style, mode, nil)) {
                    Label("Write sentences", systemImage: "text.line.first.and.arrowtriangle.forward")
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.bordered)

                if mode != .learn, let course = JourneyLibrary.shared.journey(style: settings.style) {
                    activities(course)
                }

                if let next = upNext {
                    NavigationLink(value: Route.write(mode, next.id)) {
                        HStack(spacing: 16) {
                            LetterThumbnail(template: next, lineWidth: 3.5, color: .white)
                                .frame(width: 64, height: 68)
                                .background(Color.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Up next")
                                    .font(.subheadline.weight(.semibold))
                                    .opacity(0.85)
                                Text("\(mode.rawValue) \(next.spokenName)")
                                    .font(.workbook(.title2))
                            }
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 36))
                        }
                        .foregroundStyle(.white)
                        .padding(18)
                        .background(mode.color, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                } else if !letters.isEmpty {
                    Label("Every letter passed in \(mode.rawValue). Brilliant!", systemImage: "trophy.fill")
                        .font(.workbook(.title3))
                        .foregroundStyle(mode.color)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 16)], spacing: 16) {
                    ForEach(letters) { template in
                        NavigationLink(value: Route.write(mode, template.id)) {
                            LetterTile(template: template, best: progress.best(mode, template.id), color: mode.color)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
            .padding(32)
        }
        .background(Color.paper)
        .navigationTitle(mode.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}


/// Original offline prompts, shared by the three styles.
private let sentencePrompts = [
    "The little bell fell silent.", "Rain taps the roof.", "We pack a picnic.",
    "A quiet fox crossed the yard.", "Keep the blue pencil.", "The kite rose slowly.",
    "My sister made a map.", "Look up at the moon.", "Two boats drift home.",
    "The jasmine blooms at dusk.", "Mix the lemon juice.", "Draw a circle in chalk.",
    "Five candles light the room.", "Our team plays on Friday.", "A zebra ran past.",
    "Bring your sketchbook.", "The waves reach the sand.", "Leave a note for me.",
    "Warm bread fills the basket.", "Watch the green leaves turn.", "Can you hear the train?",
    "We share the garden tools.", "The puppy found a sock.", "A small cloud floats west.",
    "Take the next left.", "The stars shine above us.", "Fold the paper twice.",
    "My jacket has two pockets.", "Fresh snow covers the path.", "Write your name here."
]

struct SentenceWorksheet: View {
    let style: LetterStyle
    let mode: WritingMode
    @State private var index: Int
    @State private var custom: String?
    @State private var draft = ""
    @State private var editing = false
    @State private var tracingWords = false
    @State private var word = 0
    @State private var finished = false
    @State private var previous: UIImage?
    @State private var wordsWritten: [UIImage] = []
    @State private var replay = UUID()
    @State private var canvasSize: CGSize = .zero
    @State private var wordResults: [LineResult] = []
    @State private var result: LineResult?
    @StateObject private var ink = InkModel()

    init(style: LetterStyle, mode: WritingMode, focus: String?) {
        self.style = style
        self.mode = mode
        _index = State(initialValue: focus.flatMap { glyph in
            sentencePrompts.firstIndex { $0.lowercased().contains(glyph.lowercased()) }
        } ?? 0)
    }

    private var sentence: String { custom ?? sentencePrompts[index] }
    private var words: [String] { sentence.split(whereSeparator: { $0.isWhitespace }).map(String.init) }
    private var model: String { tracingWords ? words[word] : sentence }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(style.title) · \(mode.rawValue)").font(.headline).foregroundStyle(.secondary)
                Text(sentence).font(.workbook(.title))
                if mode != .test && !finished {
                    Toggle("Trace word by word", isOn: $tracingWords)
                        .disabled(ink.strokeCount > 0 || !wordsWritten.isEmpty)
                        .onChange(of: tracingWords) { _, _ in reset() }
                }
                if tracingWords {
                    HStack {
                        Text("Word \(word + 1) of \(words.count)").font(.headline)
                        Spacer()
                        Button("Replay") { replay = UUID() }
                    }
                    SentenceModel(text: model, style: style, animated: true).id(replay)
                        .frame(height: 75)
                } else if mode == .practice || finished {
                    SentenceModel(text: sentence, style: style, animated: false).frame(height: 85)
                }
                if let previous {
                    Text("Previous attempt").font(.caption)
                    Image(uiImage: previous).resizable().scaledToFit().frame(maxHeight: 105)
                }
                if tracingWords && !wordsWritten.isEmpty {
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(wordsWritten.indices, id: \.self) { i in
                                Image(uiImage: wordsWritten[i]).resizable().scaledToFit().frame(height: 64)
                            }
                        }
                    }
                }
                GeometryReader { geo in
                ZStack {
                    RuledLinesView(layout: SentenceModel.layout(text: model, style: style, size: geo.size))
                    if tracingWords {
                        SentenceModel(text: model, style: style, animated: false)
                            .opacity(0.3).allowsHitTesting(false)
                    }
                    InkCanvas(model: ink).allowsHitTesting(!finished)
                }
                .onAppear { canvasSize = geo.size }
                .onChange(of: geo.size) { _, newSize in canvasSize = newSize }
                }
                .frame(height: tracingWords ? 150 : 240)
                .background(Color.paper).clipShape(RoundedRectangle(cornerRadius: 14))
                if finished, let result {
                    SentenceResultCard(result: result)
                }
                if finished {
                    Text("Compare the spacing, height and joins with the model above.").font(.callout)
                    HStack {
                        Button("Next sentence") {
                            index = (index + 1) % sentencePrompts.count
                            custom = nil
                            reset()
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Write again") {
                            let last = comparisonImage()
                            reset()
                            previous = last
                        }
                    }
                } else {
                    HStack {
                        Button(tracingWords && word + 1 < words.count ? "Next word" : "Finish sentence") {
                            if tracingWords && word + 1 < words.count {
                                if let image = snapshot() { wordsWritten.append(image) }
                                scoreCurrent()
                                ink.clear()
                                word += 1
                                replay = UUID()
                            } else {
                                scoreCurrent()
                                finished = true
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(ink.strokeCount == 0 || ink.isDrawing)
                        Button("Undo") { ink.undo() }.disabled(ink.strokeCount == 0)
                    }
                }
                Button("Write my own sentence") { draft = custom ?? ""; editing = true }
            }
            .padding(24).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }
        .background(Color.paperCard)
        .navigationTitle("Sentence worksheet")
        .onAppear { ink.pencilOnly = AppSettings.shared.pencilOnly }
        .sheet(isPresented: $editing) {
            NavigationStack {
                Form {
                    TextField("Your sentence", text: $draft, axis: .vertical)
                    Text("Up to 100 characters").font(.caption)
                }
                .navigationTitle("Write my own")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { editing = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Use sentence") {
                            custom = draft.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
                            reset()
                            editing = false
                        }
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.count > 100)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }

    /// Scores what is on the canvas: one word when tracing word by word,
    /// otherwise the whole sentence written freely.
    private func scoreCurrent() {
        guard canvasSize != .zero, let plan = try? CoreBridge.plan(model, style: style), !plan.isEmpty else { return }
        let layout = SentenceModel.layout(text: model, style: style, size: canvasSize)
        let r = CoreBridge.scoreLine(strokes: ink.capturedStrokes(in: layout), plan: plan,
                                     traced: false, finger: ink.lastInkUsedFinger)
        if tracingWords {
            wordResults.append(r)
            if wordResults.count == words.count || word + 1 >= words.count { result = combined(wordResults) }
        } else {
            result = r
        }
        if let result {
            ProgressStore.shared.record(score: result.overall, mode: mode,
                                        templateID: "sentence.\(style.rawValue)", issue: result.kinds.first)
        }
    }

    /// Word-by-word results combined into one sentence result.
    private func combined(_ parts: [LineResult]) -> LineResult {
        let overall = parts.isEmpty ? 0 : parts.map(\.overall).reduce(0, +) / parts.count
        let worst = parts.min { $0.overall < $1.overall }
        var merged: [String: [Int]] = [:]
        for part in parts { for p in part.parts { merged[p.name, default: []].append(p.value) } }
        let names = ["Shape", "Size", "Baseline", "Smoothness"]
        return LineResult(
            overall: overall,
            tip: worst?.tip,
            kinds: worst?.kinds ?? [],
            messages: worst?.messages ?? [],
            parts: names.compactMap { n in merged[n].map { ScorePart(name: n, value: $0.reduce(0, +) / $0.count) } },
            words: parts.flatMap(\.words),
            letterScores: parts.flatMap(\.letterScores),
            problemLetters: []
        )
    }

    private func comparisonImage() -> UIImage? {
        guard let last = snapshot() else { return nil }
        let images = wordsWritten + [last]
        guard images.count > 1 else { return last }
        let height: CGFloat = 68
        let widths = images.map { min(160, height * $0.size.width / max(1, $0.size.height)) }
        let size = CGSize(width: widths.reduce(0, +) + CGFloat(images.count) * 8, height: height)
        return UIGraphicsImageRenderer(size: size).image { _ in
            var x: CGFloat = 0
            for (i, image) in images.enumerated() {
                let scale = min(widths[i] / image.size.width, height / image.size.height)
                let h = image.size.height * scale
                image.draw(in: CGRect(x: x, y: height - h, width: image.size.width * scale, height: h))
                x += widths[i] + 8
            }
        }
    }

    private func snapshot() -> UIImage? {
        let drawing = ink.drawing
        guard !drawing.strokes.isEmpty else { return nil }
        return drawing.image(from: drawing.bounds.insetBy(dx: -6, dy: -6), scale: 1)
    }

    private func reset() {
        ink.clear()
        word = 0
        finished = false
        result = nil
        wordResults.removeAll()
        previous = nil
        wordsWritten.removeAll()
        replay = UUID()
    }
}

/// Draws the sentence from the letter templates (lowercase and capitals);
/// punctuation keeps its printed form. Capitals don't join on to the next letter.
private struct SentenceModel: View {
    let text: String
    let style: LetterStyle
    let animated: Bool
    @State private var started = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Where the model's writing lines sit for this text and size, so guides
    /// and ink line up with the drawn model.
    static func layout(text: String, style: LetterStyle, size: CGSize) -> GuideLayout {
        let space: CGFloat = style == .print ? 0.18 : 0.08
        let total = text.map(String.init).reduce(CGFloat(0)) { sum, glyph in
            if let t = TemplateLibrary.shared.template(id: "latin.\(style.rawValue).\(glyph)") { return sum + CGFloat(t.width) + space }
            return sum + (glyph == " " ? 0.48 : 0.85)
        }
        let unit = max(1, min(size.height / 1.65, (size.width - 20) / max(1, total)))
        return GuideLayout(origin: CGPoint(x: 10, y: (size.height - 1.5 * unit) / 2), unit: unit)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animated || reduceMotion)) { clock in
        Canvas { context, size in
            let fraction = CGFloat(min(1, max(0, clock.date.timeIntervalSince(started)) / max(1, Double(text.count) * 0.24)))
            let glyphs = text.map(String.init)
            let templates = glyphs.map { TemplateLibrary.shared.template(id: "latin.\(style.rawValue).\($0)") }
            let space: CGFloat = style == .print ? 0.18 : 0.08
            let widths: [CGFloat] = glyphs.indices.map { i in
                if let template = templates[i] { return CGFloat(template.width) + space }
                return glyphs[i] == " " ? 0.48 : 0.85
            }
            let unit = min(size.height / 1.65, (size.width - 20) / max(1, widths.reduce(0, +)))
            let top = (size.height - 1.5 * unit) / 2
            var x: CGFloat = 10
            var lastExit: CGPoint?
            for i in glyphs.indices {
                let part = animated && !reduceMotion ? min(1, max(0, fraction * CGFloat(glyphs.count) - CGFloat(i))) : 1
                guard part > 0 else { break }
                if let t = templates[i] {
                    var path = Path()
                    for (j, stroke) in t.strokes.enumerated() {
                        let points = stroke.cgPoints.map { CGPoint(x: x + $0.x * unit, y: top + $0.y * unit) }
                        guard let first = points.first else { continue }
                        if j == 0, style != .print, let lastExit {
                            path.move(to: lastExit)
                            path.addLine(to: first)
                        } else { path.move(to: first) }
                        for point in points.dropFirst() { path.addLine(to: point) }
                        if j == 0 { lastExit = t.glyph.lowercased() == t.glyph ? points.last : nil }
                    }
                    context.stroke(path.trimmedPath(from: 0, to: part), with: .color(.ink),
                                   style: StrokeStyle(lineWidth: max(1.5, unit * 0.045), lineCap: .round, lineJoin: .round))
                } else {
                    context.draw(Text(glyphs[i]).font(.system(size: unit * 1.24, design: .rounded)).foregroundColor(.ink),
                                 at: CGPoint(x: x, y: top + unit * 1.15), anchor: .bottomLeading)
                    lastExit = nil
                }
                x += widths[i] * unit
            }
        }
        }
        .accessibilityLabel(text)
    }
}

/// The sentence score: overall ring, the one tip, each word's score and the
/// line metrics (shape, size, baseline, spacing, smoothness).
private struct SentenceResultCard: View {
    let result: LineResult

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 18) {
                ScoreRing(score: result.overall, size: 76)
                VStack(alignment: .leading, spacing: 6) {
                    Label(result.tip == nil ? "Lovely sentence" : "One thing to work on",
                          systemImage: result.tip == nil ? "checkmark.seal.fill" : "lightbulb.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(result.tip == nil ? Color.green : Color.orange)
                    Text(result.tip ?? "Even size, steady baseline and clear words.")
                        .font(.workbook(.title3))
                        .foregroundStyle(Color.ink)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(result.words.enumerated()), id: \.offset) { _, word in
                        HStack(spacing: 6) {
                            Text(word.text).font(.headline)
                            Text("\(word.score)").font(.callout.weight(.bold)).foregroundStyle(scoreColor(word.score))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(scoreColor(word.score).opacity(0.12), in: Capsule())
                    }
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), alignment: .leading)], alignment: .leading, spacing: 8) {
                ForEach(result.parts) { PartChip(part: $0) }
            }
        }
        .padding(18)
        .paperCard(radius: 20)
    }
}
