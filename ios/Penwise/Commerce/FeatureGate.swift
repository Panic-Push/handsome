import Foundation

/// What is free and what needs Premium. The front end asks before opening a
/// feature and shows the paywall when the answer is no.
///
/// Free: the whole Normal course, Learn and Practice everywhere, the first
/// chapter of Classic and Traditional, the assessment and report, today's
/// first plan activity, 3 tests, 3 word sessions and 1 sentence a day.
/// Premium: everything, with no ads.
@MainActor
enum FeatureGate {
    static let freeTestsPerDay = 3
    static let freeWordSessionsPerDay = 3
    static let freeSentencesPerDay = 1

    enum Feature: String {
        case test, words, sentence
    }

    private static var isPremium: Bool { StoreService.shared.isPremium }

    /// Whether a chapter of a style's journey can be opened.
    static func canOpen(chapterIndex: Int, style: LetterStyle) -> Bool {
        isPremium || style == .print || chapterIndex == 0
    }

    /// Whether a plan activity can be opened (the first of each day is free).
    static func canOpen(planItemAt index: Int) -> Bool {
        isPremium || index == 0
    }

    static func remainingToday(_ feature: Feature) -> Int? {
        guard !isPremium else { return nil }
        return max(0, limit(feature) - usedToday(feature))
    }

    /// True if the feature can start now. Call `recordUse` once it starts.
    static func canStart(_ feature: Feature) -> Bool {
        isPremium || usedToday(feature) < limit(feature)
    }

    static func recordUse(_ feature: Feature) {
        guard !isPremium else { return }
        UserDefaults.standard.set(usedToday(feature) + 1, forKey: key(feature))
    }

    private static func limit(_ feature: Feature) -> Int {
        switch feature {
        case .test: return freeTestsPerDay
        case .words: return freeWordSessionsPerDay
        case .sentence: return freeSentencesPerDay
        }
    }

    private static func usedToday(_ feature: Feature) -> Int {
        UserDefaults.standard.integer(forKey: key(feature))
    }

    private static func key(_ feature: Feature) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return "penwise.gate.\(feature.rawValue).\(f.string(from: Date()))"
    }
}
