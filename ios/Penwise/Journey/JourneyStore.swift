import Foundation

/// Journey progress saved on this iPad: the resume position, completed steps,
/// letters flagged for review, checkpoint picks, and first/latest samples.
final class JourneyStore: ObservableObject {
    static let shared = JourneyStore()

    /// A memory attempt below this flags the letter for review; at or above
    /// `ProgressStore.passMark` the flag is cleared.
    static let reviewBelow = 70

    private struct Saved: Codable {
        var positions: [String: LessonPosition] = [:]
        var completed: Set<String> = []
        var review: Set<String> = []
        var checkpointPicks: [String: [String]] = [:]
        var firstSamples: [String: [CapturedStroke]] = [:]
        var latestSamples: [String: [CapturedStroke]] = [:]
        var lastIssue: [String: String] = [:]
    }

    @Published private var saved: Saved
    private let storageKey = "penwise.journeys.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(Saved.self, from: data) {
            saved = decoded
            migrateExpandedCourses()
        } else {
            saved = Saved()
        }
    }

    private func migrateExpandedCourses() {
        var changed = false
        for journey in JourneyLibrary.shared.journeys {
            guard let checkpoint = journey.chapters.first(where: { $0.isCheckpoint }),
                  let position = saved.positions[journey.id],
                  position.chapterID == checkpoint.id else { continue }
            let key = pickKey(journey, checkpoint)
            if let picks = saved.checkpointPicks[key], picks.count < (checkpoint.pick ?? picks.count) {
                let extra = suggestedPicks(checkpoint, in: journey) + checkpoint.letters
                var expanded = picks
                for glyph in extra where !expanded.contains(glyph) && expanded.count < (checkpoint.pick ?? 4) {
                    expanded.append(glyph)
                }
                saved.checkpointPicks[key] = expanded
                changed = true
            }
            for chapter in journey.chapters where !chapter.isCheckpoint {
                if let index = chapter.letters.firstIndex(where: { !isComplete($0, chapter, in: journey) }) {
                    saved.positions[journey.id] = LessonPosition(journeyID: journey.id, chapterID: chapter.id,
                                                                 letterIndex: index, step: .watch)
                    changed = true
                    break
                }
            }
        }
        if changed { persist() }
    }

    // MARK: - Letters and completion

    /// Letters of a chapter. A checkpoint uses its saved picks, or a preview
    /// of what would be picked now.
    func letters(_ chapter: Journey.Chapter, in journey: Journey) -> [String] {
        guard chapter.isCheckpoint else { return chapter.letters }
        return saved.checkpointPicks[pickKey(journey, chapter)] ?? suggestedPicks(chapter, in: journey)
    }

    /// Fixes the checkpoint letters when the checkpoint starts.
    func lockCheckpointPicks(_ chapter: Journey.Chapter, in journey: Journey) {
        guard chapter.isCheckpoint, saved.checkpointPicks[pickKey(journey, chapter)] == nil else { return }
        saved.checkpointPicks[pickKey(journey, chapter)] = suggestedPicks(chapter, in: journey)
        persist()
    }

    func isComplete(_ glyph: String, _ chapter: Journey.Chapter, in journey: Journey) -> Bool {
        chapter.scoredSteps.allSatisfy { saved.completed.contains(stepKey(journey.id, chapter.id, glyph, $0)) }
    }

    func completedCount(_ chapter: Journey.Chapter, in journey: Journey) -> Int {
        letters(chapter, in: journey).filter { isComplete($0, chapter, in: journey) }.count
    }

    func isChapterComplete(_ chapter: Journey.Chapter, in journey: Journey) -> Bool {
        let list = letters(chapter, in: journey)
        return !list.isEmpty && list.allSatisfy { isComplete($0, chapter, in: journey) }
    }

    func isFinished(_ journey: Journey) -> Bool {
        journey.chapters.allSatisfy { isChapterComplete($0, in: journey) }
    }

    func needsReview(_ glyph: String, in journey: Journey) -> Bool {
        saved.review.contains(letterKey(journey.id, glyph))
    }

    func markComplete(_ position: LessonPosition, glyph: String) {
        saved.completed.insert(stepKey(position.journeyID, position.chapterID, glyph, position.step))
        persist()
    }

    // MARK: - Position

    func hasStarted(_ journey: Journey) -> Bool { saved.positions[journey.id] != nil }

    /// The saved step to resume, or the very first step.
    func position(in journey: Journey) -> LessonPosition {
        if let p = saved.positions[journey.id], let chapter = journey.chapter(p.chapterID) {
            let glyphs = letters(chapter, in: journey)
            if glyphs.indices.contains(p.letterIndex), !isComplete(glyphs[p.letterIndex], chapter, in: journey) { return p }
            for unit in journey.chapters {
                if let index = letters(unit, in: journey).firstIndex(where: { !isComplete($0, unit, in: journey) }) {
                    return LessonPosition(journeyID: journey.id, chapterID: unit.id, letterIndex: index, step: unit.steps[0])
                }
            }
            return p
        }
        let first = journey.chapters.first
        return LessonPosition(journeyID: journey.id, chapterID: first?.id ?? "", letterIndex: 0,
                              step: first?.steps.first ?? .watch)
    }

    func setPosition(_ position: LessonPosition) {
        saved.positions[position.journeyID] = position
        persist()
    }

    /// The step after this one: next step of the letter, next letter, next
    /// chapter, or nil at the end of the journey.
    func next(after p: LessonPosition, in journey: Journey) -> LessonPosition? {
        guard let index = journey.chapterIndex(p.chapterID) else { return nil }
        let chapter = journey.chapters[index]
        if let s = chapter.steps.firstIndex(of: p.step), s + 1 < chapter.steps.count {
            return LessonPosition(journeyID: p.journeyID, chapterID: chapter.id, letterIndex: p.letterIndex,
                                  step: chapter.steps[s + 1])
        }
        if p.letterIndex + 1 < letters(chapter, in: journey).count {
            return LessonPosition(journeyID: p.journeyID, chapterID: chapter.id, letterIndex: p.letterIndex + 1,
                                  step: chapter.steps[0])
        }
        guard index + 1 < journey.chapters.count else { return nil }
        let nextChapter = journey.chapters[index + 1]
        return LessonPosition(journeyID: p.journeyID, chapterID: nextChapter.id, letterIndex: 0,
                              step: nextChapter.steps[0])
    }

    // MARK: - Memory attempts (review flags, recap samples)

    func noteMemoryAttempt(journey: Journey, glyph: String, strokes: [CapturedStroke], score: Int, issue: String?) {
        let key = letterKey(journey.id, glyph)
        if saved.firstSamples[key] == nil { saved.firstSamples[key] = strokes }
        saved.latestSamples[key] = strokes
        saved.lastIssue[key] = issue
        if score < JourneyStore.reviewBelow {
            saved.review.insert(key)
        } else if score >= ProgressStore.passMark {
            saved.review.remove(key)
        }
        persist()
    }

    func samples(_ glyph: String, in journey: Journey) -> (first: [CapturedStroke], latest: [CapturedStroke])? {
        let key = letterKey(journey.id, glyph)
        guard let first = saved.firstSamples[key], let latest = saved.latestSamples[key] else { return nil }
        return (first, latest)
    }

    /// The letter most worth revisiting and why, e.g. ("a", "Revisit a to practice closing the loop.").
    func suggestion(in journey: Journey) -> (glyph: String, text: String)? {
        let glyphs = Array(Set(journey.chapters.flatMap(\.letters)))
        guard let weakest = weakest(glyphs, in: journey) else { return nil }
        let issue = saved.lastIssue[letterKey(journey.id, weakest)]
        return (weakest, "Revisit \(weakest) to practice \(JourneyStore.practicePhrase(issue, glyph: weakest)).")
    }

    func reset() {
        saved = Saved()
        persist()
    }

    // MARK: - Private

    /// Flagged letters first, then the lowest independent (Test) score.
    private func weakest(_ glyphs: [String], in journey: Journey) -> String? {
        let progress = ProgressStore.shared
        return glyphs.min { a, b in
            let fa = needsReview(a, in: journey) ? 0 : 1
            let fb = needsReview(b, in: journey) ? 0 : 1
            if fa != fb { return fa < fb }
            let sa = progress.best(.test, journey.templateID(a)) ?? -1
            let sb = progress.best(.test, journey.templateID(b)) ?? -1
            return sa != sb ? sa < sb : a < b
        }
    }

    /// Letters from each earlier chapter in turn, then the weakest letter last.
    private func suggestedPicks(_ chapter: Journey.Chapter, in journey: Journey) -> [String] {
        let count = min(chapter.pick ?? 4, chapter.letters.count)
        let weak = weakest(chapter.letters, in: journey)
        let target = weak == nil ? count : count - 1
        let groups = journey.chapters
            .filter { !$0.isCheckpoint }
            .map { $0.letters.filter { chapter.letters.contains($0) && $0 != weak } }

        var picks: [String] = []
        var level = 0
        while picks.count < target && groups.contains(where: { level < $0.count }) {
            for group in groups where level < group.count && picks.count < target {
                picks.append(group[level])
            }
            level += 1
        }
        if let weak { picks.append(weak) }
        return picks
    }

    static func practicePhrase(_ issue: String?, glyph: String) -> String {
        switch issue {
        case "STROKE_DIRECTION": return "the stroke direction"
        case "START_POINT": return "where each stroke starts"
        case "OFF_BASELINE": return "sitting on the baseline"
        case "TOO_BIG", "TOO_SMALL": return "the letter size"
        case "SHAKY": return "smooth, steady lines"
        case "STROKE_ORDER", "STROKE_COUNT": return "the stroke order"
        case "MISSING_STROKE": return glyph == "t" ? "the crossbar" : glyph == "i" ? "the dot" : "the finishing strokes"
        default: return ["o", "a", "d"].contains(glyph) ? "closing the loop" : glyph == "c" ? "the open curve" : "the shape"
        }
    }

    private func stepKey(_ journey: String, _ chapter: String, _ glyph: String, _ step: LessonStep) -> String {
        "\(journey)|\(chapter)|\(glyph)|\(step.rawValue)"
    }

    private func letterKey(_ journey: String, _ glyph: String) -> String { "\(journey)|\(glyph)" }
    private func pickKey(_ journey: Journey, _ chapter: Journey.Chapter) -> String { "\(journey.id)|\(chapter.id)" }

    private func persist() {
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
