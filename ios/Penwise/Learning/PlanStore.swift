import Foundation

/// The learner's report and daily plan, saved on this iPad.
///
/// Front end: observe `report`, `today` and `minutesPerDay`; call
/// `markDone(_:)` when an activity is finished and `route(for:)` to open it.
final class PlanStore: ObservableObject {
    static let shared = PlanStore()

    /// Minutes a day the learner wants to practise (5 to 30).
    static let minuteChoices = [5, 10, 15, 20, 30]

    private struct Saved: Codable {
        var report: HandwritingReport?
        var history: [HandwritingReport] = []
        var minutesPerDay = 10
        var planStart: Date?
        var done: [String: [String]] = [:]
    }

    @Published private(set) var report: HandwritingReport?
    @Published private(set) var today: PlanDay?
    @Published var minutesPerDay: Int {
        didSet {
            saved.minutesPerDay = minutesPerDay
            persist()
            refresh()
        }
    }

    private var saved: Saved
    private let storageKey = "penwise.plan.v1"

    private init() {
        let loaded = UserDefaults.standard.data(forKey: storageKey)
            .flatMap { try? JSONDecoder().decode(Saved.self, from: $0) } ?? Saved()
        saved = loaded
        report = loaded.report
        minutesPerDay = loaded.minutesPerDay
        refresh()
    }

    // MARK: - Reading

    /// True until the starting assessment has been taken.
    var needsAssessment: Bool { report == nil }

    /// Earlier reports, oldest first (for showing progress over time).
    var history: [HandwritingReport] { saved.history }

    /// Days since the plan started (0 on the assessment day).
    var dayIndex: Int {
        guard let start = saved.planStart else { return 0 }
        let calendar = Calendar.current
        return max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: start),
                                              to: calendar.startOfDay(for: Date())).day ?? 0)
    }

    /// True when it is time to take the assessment again.
    var reassessmentDue: Bool {
        guard let today else { return false }
        return dayIndex >= today.reassessAfterDays
    }

    func isDone(_ item: PlanItem) -> Bool {
        saved.done[dayKey(Date())]?.contains(item.id) ?? false
    }

    /// Finished and total activities today.
    var progressToday: (done: Int, total: Int) {
        let items = today?.items ?? []
        return (items.filter(isDone).count, items.count)
    }

    // MARK: - Writing

    /// Saves a new report and restarts the plan from day 0.
    func save(report: HandwritingReport) {
        saved.report = report
        saved.history.append(report)
        saved.history = Array(saved.history.suffix(12))
        saved.planStart = Date()
        persist()
        self.report = report
        refresh()
    }

    func markDone(_ item: PlanItem) {
        let key = dayKey(Date())
        var list = saved.done[key] ?? []
        if !list.contains(item.id) { list.append(item.id) }
        saved.done[key] = list
        // Keep two weeks of ticks.
        let keys = saved.done.keys.sorted()
        if keys.count > 14 { keys.prefix(keys.count - 14).forEach { saved.done[$0] = nil } }
        persist()
        objectWillChange.send()
    }

    /// Rebuilds today's plan (call when the app returns to the foreground on a new day).
    func refresh() {
        guard let report else {
            today = nil
            return
        }
        today = LearningBridge.plan(for: report, minutes: minutesPerDay, day: dayIndex)
    }

    func reset() {
        saved = Saved()
        persist()
        report = nil
        minutesPerDay = 10
        today = nil
    }

    // MARK: - Opening an activity

    /// Where an activity takes the learner. Letter lessons open the journey
    /// lesson for that letter (as a review, so the journey place is kept).
    func route(for item: PlanItem, style: LetterStyle) -> Route {
        let ids = item.letters.map { "latin.\(style.rawValue).\($0)" }
        switch item.kind {
        case .letterLesson:
            if item.letters.count == 1, let position = lessonPosition(for: item.letters[0], style: style) {
                return .lesson(position, review: true)
            }
            return .set(.learn, item.title, ids)
        case .letterPractice:
            return .set(.practice, item.title, ids)
        case .letterTest:
            return .set(.test, item.title, ids, shuffled: true)
        case .words:
            return .words(WordRequest(style: style, letters: item.letters, focus: item.focus, planItemID: item.id))
        case .sentence:
            return .sentences(style, .practice, nil)
        }
    }

    private func lessonPosition(for glyph: String, style: LetterStyle) -> LessonPosition? {
        guard let journey = JourneyLibrary.shared.journey(style: style),
              let chapter = journey.chapters.first(where: { !$0.isCheckpoint && $0.letters.contains(glyph) }),
              let index = chapter.letters.firstIndex(of: glyph) else { return nil }
        return LessonPosition(journeyID: journey.id, chapterID: chapter.id, letterIndex: index, step: chapter.steps[0])
    }

    private func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
