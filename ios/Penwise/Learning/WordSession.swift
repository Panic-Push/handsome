import CoreGraphics
import Foundation

/// What a word practice screen should practise.
struct WordRequest: Hashable {
    let style: LetterStyle
    /// Letters the words should contain (may be empty).
    let letters: [String]
    /// Skill to emphasise, e.g. "BASELINE" or "SIZE" (nil for none).
    let focus: String?
    /// The plan item to tick off when finished, if opened from the plan.
    let planItemID: String?
}

/// A run of practice words written one after another on a line.
///
/// Front end: show `word` (and draw `plan` faintly when `traced` is true),
/// draw guides with `layout(in:)`, convert ink with
/// `InkModel.capturedStrokes(in: layout(in: size))`, call `submit(...)`, show
/// `lastResult` quietly, then `next()`. `isFinished` ends the run; the
/// summary is in `average`, `best` and `results`.
final class WordSession: ObservableObject {
    let request: WordRequest
    let words: [String]
    /// The first two words are written over a faint model, the rest freely.
    let tracedCount = 2

    @Published private(set) var index = 0
    @Published private(set) var lastResult: LineResult?
    @Published private(set) var results: [LineResult] = []

    init(request: WordRequest, count: Int = 6) {
        self.request = request
        let journey = JourneyLibrary.shared.journey(style: request.style)
        var known: [String]? = nil
        if let journey {
            let done = journey.chapters.filter { !$0.isCheckpoint }.flatMap { chapter in
                chapter.letters.filter { JourneyStore.shared.isComplete($0, chapter, in: journey) }
            }
            // Only restrict to known letters once enough have been learned.
            if done.count >= 8 { known = Array(Set(done + request.letters)) }
        }
        let seed = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        var picked = LearningBridge.words(focus: request.letters, allowed: known, count: count, seed: seed)
        if picked.isEmpty {
            picked = LearningBridge.words(focus: request.letters, allowed: nil, count: count, seed: seed)
        }
        words = picked
    }

    var word: String? { words.indices.contains(index) ? words[index] : nil }
    var traced: Bool { index < tracedCount }
    var isFinished: Bool { !words.isEmpty && index >= words.count }
    var progress: Double { words.isEmpty ? 1 : Double(index) / Double(words.count) }

    var plan: LinePlan? {
        guard let word else { return nil }
        return try? CoreBridge.plan(word, style: request.style)
    }

    var average: Int { results.isEmpty ? 0 : results.map(\.overall).reduce(0, +) / results.count }
    var best: Int { results.map(\.overall).max() ?? 0 }

    /// Ruled lines for the current word in a canvas of `size`.
    func layout(in size: CGSize) -> GuideLayout {
        let width = (plan?.width ?? 2) + 0.8
        let unit = max(30, min(size.height / 1.8, size.width / width))
        let left = (size.width - (plan?.width ?? 2) * unit) / 2
        return GuideLayout(origin: CGPoint(x: left, y: (size.height - 1.5 * unit) / 2), unit: unit)
    }

    /// Scores the current word. The tip prefers the focus skill when it applies.
    @discardableResult
    func submit(strokes: [CapturedStroke], finger: Bool) -> LineResult? {
        guard let plan, !strokes.isEmpty else { return nil }
        let raw = CoreBridge.scoreLine(strokes: strokes, plan: plan, traced: traced, finger: finger)
        let result = preferringFocus(raw)
        lastResult = result
        results.append(result)
        ProgressStore.shared.record(score: result.overall, mode: traced ? .practice : .test,
                                    templateID: "words.\(request.style.rawValue)", issue: result.kinds.first)
        return result
    }

    /// Moves to the next word; ticks the plan item off at the end.
    func next() {
        lastResult = nil
        index += 1
        if isFinished, let id = request.planItemID, let item = PlanStore.shared.today?.items.first(where: { $0.id == id }) {
            PlanStore.shared.markDone(item)
        }
    }

    /// Lets the learner write the same word again (drops the last result).
    func retry() {
        if lastResult != nil { results.removeLast() }
        lastResult = nil
    }

    private func preferringFocus(_ r: LineResult) -> LineResult {
        guard let focus = request.focus else { return r }
        let wanted: [String]
        switch focus {
        case "BASELINE": wanted = ["OFF_BASELINE"]
        case "SIZE": wanted = ["UNEVEN_SIZE", "TOO_BIG", "TOO_SMALL"]
        case "SPACING": wanted = ["UNEVEN_SPACING"]
        case "SMOOTHNESS": wanted = ["SHAKY"]
        default: wanted = []
        }
        guard let i = r.kinds.firstIndex(where: wanted.contains), i < r.messages.count else { return r }
        return LineResult(overall: r.overall, tip: r.messages[i], kinds: r.kinds, messages: r.messages,
                          parts: r.parts, words: r.words, letterScores: r.letterScores, problemLetters: r.problemLetters)
    }
}
