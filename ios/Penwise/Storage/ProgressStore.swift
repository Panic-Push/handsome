import Foundation

/// Best scores, attempts and practice days, saved on this iPad only.
final class ProgressStore: ObservableObject {
    static let shared = ProgressStore()

    /// A letter counts as passed in a mode at this score or above.
    static let passMark = 80

    struct Entry: Codable {
        /// Best score without hints.
        var best: Int
        var attempts: Int
        var last: Date
    }

    struct Attempt: Codable {
        var score: Int
        var date: Date
        /// True when the guide was peeked at during a Test attempt.
        var hinted: Bool
    }

    private struct Saved: Codable {
        var entries: [String: Entry] = [:]
        /// Number of checked letters per day, keyed "yyyy-MM-dd".
        var attemptsByDay: [String: Int] = [:]
        var lastMode: String?
        var lastTemplateID: String?
        /// Recent attempts per letter and mode (newest last).
        var history: [String: [Attempt]]?
    }

    @Published private var saved: Saved
    private let storageKey = "penwise.progress.v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(Saved.self, from: data) {
            saved = decoded
        } else {
            saved = Saved()
        }
    }

    // MARK: - Recording

    func record(score: Int, mode: WritingMode, templateID: String, hinted: Bool = false) {
        let key = ProgressStore.key(mode, templateID)
        var entry = saved.entries[key] ?? Entry(best: 0, attempts: 0, last: Date())
        if !hinted { entry.best = max(entry.best, score) }
        entry.attempts += 1
        entry.last = Date()
        saved.entries[key] = entry

        var history = saved.history ?? [:]
        var list = history[key] ?? []
        list.append(Attempt(score: score, date: Date(), hinted: hinted))
        history[key] = Array(list.suffix(20))
        saved.history = history

        let today = ProgressStore.dayString(Date())
        saved.attemptsByDay[today, default: 0] += 1
        saved.lastMode = mode.rawValue
        saved.lastTemplateID = templateID
        persist()
    }

    // MARK: - Reading

    func entry(_ mode: WritingMode, _ templateID: String) -> Entry? {
        saved.entries[ProgressStore.key(mode, templateID)]
    }

    func best(_ mode: WritingMode, _ templateID: String) -> Int? {
        entry(mode, templateID)?.best
    }

    /// Most recent attempts first.
    func recentAttempts(_ mode: WritingMode, _ templateID: String, limit: Int = 5) -> [Attempt] {
        Array((saved.history?[ProgressStore.key(mode, templateID)] ?? []).suffix(limit).reversed())
    }

    /// Letters with at least one attempt in this mode.
    func practicedCount(_ mode: WritingMode, templateIDs: [String]) -> Int {
        templateIDs.filter { entry(mode, $0) != nil }.count
    }

    var isFirstVisit: Bool { saved.lastTemplateID == nil }

    func reset() {
        saved = Saved()
        persist()
    }

    func passedCount(_ mode: WritingMode, templateIDs: [String]) -> Int {
        templateIDs.filter { (best(mode, $0) ?? 0) >= ProgressStore.passMark }.count
    }

    var attemptsToday: Int {
        saved.attemptsByDay[ProgressStore.dayString(Date())] ?? 0
    }

    /// Consecutive days with practice, counting today or ending yesterday.
    var streak: Int {
        let calendar = Calendar.current
        var day = Date()
        if saved.attemptsByDay[ProgressStore.dayString(day)] == nil {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while saved.attemptsByDay[ProgressStore.dayString(day)] != nil {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    var lastPlayed: (mode: WritingMode, templateID: String)? {
        guard let raw = saved.lastMode, let mode = WritingMode(rawValue: raw),
              let id = saved.lastTemplateID else { return nil }
        return (mode, id)
    }

    /// 0 to 3 stars for a score.
    static func stars(for score: Int?) -> Int {
        guard let score else { return 0 }
        if score >= 90 { return 3 }
        if score >= 75 { return 2 }
        if score >= 60 { return 1 }
        return 0
    }

    // MARK: - Private

    private func persist() {
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private static func key(_ mode: WritingMode, _ id: String) -> String {
        "\(mode.rawValue)|\(id)"
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static func dayString(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }
}
