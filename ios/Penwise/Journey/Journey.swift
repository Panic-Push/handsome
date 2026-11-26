import Foundation

/// One step inside a letter lesson.
enum LessonStep: String, Codable, CaseIterable {
    case watch
    case trace
    case guided
    case memory

    var title: String {
        switch self {
        case .watch: return "Watch"
        case .trace: return "Trace"
        case .guided: return "Light guide"
        case .memory: return "Write from memory"
        }
    }

    /// The scoring mode used for this step.
    var mode: WritingMode { self == .memory ? .test : (self == .guided ? .practice : .learn) }
}

/// A course of chapters, loaded from /content/journeys (shared with Android).
struct Journey: Codable, Identifiable, Hashable {
    struct Chapter: Codable, Identifiable, Hashable {
        let id: String
        let title: String
        let goal: String
        let letters: [String]
        let checkpoint: Bool?
        let pick: Int?

        var isCheckpoint: Bool { checkpoint ?? false }

        /// Steps the learner goes through for each letter.
        var steps: [LessonStep] { isCheckpoint ? [.memory] : [.watch, .trace, .guided, .memory] }

        /// Steps that count towards completing a letter (Watch is not scored).
        var scoredSteps: [LessonStep] { isCheckpoint ? [.memory] : [.trace, .memory] }
    }

    let id: String
    let title: String
    let subtitle: String
    let style: String
    let chapters: [Chapter]

    func chapter(_ id: String) -> Chapter? { chapters.first { $0.id == id } }
    func chapterIndex(_ id: String) -> Int? { chapters.firstIndex { $0.id == id } }

    /// Template id for a letter of this journey, e.g. "latin.print-modern.o".
    func templateID(_ glyph: String) -> String { "latin.\(style).\(glyph)" }
}

/// Statistics for the current six-space worksheet, including retries.
struct LetterRun: Codable, Hashable {
    static let count = 6
    var scores: [Int] = []
    var attempts = 0
    var total = 0
    var best = 0

    var average: Int { attempts == 0 ? 0 : Int((Double(total) / Double(attempts)).rounded()) }
    var complete: Bool { scores.count >= Self.count }

    mutating func record(_ score: Int) {
        attempts += 1
        total += score
        best = max(best, score)
    }
}

/// Where a learner is in a journey: chapter, letter and step.
struct LessonPosition: Codable, Hashable {
    var journeyID: String
    var chapterID: String
    var letterIndex: Int
    var step: LessonStep
    var worksheet: LetterRun? = nil
}

final class JourneyLibrary {
    static let shared = JourneyLibrary()

    let journeys: [Journey]

    private init() {
        guard let root = Bundle.main.url(forResource: "journeys", withExtension: nil),
              let files = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
        else {
            journeys = []
            return
        }
        let decoder = JSONDecoder()
        journeys = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url in (try? Data(contentsOf: url)).flatMap { try? decoder.decode(Journey.self, from: $0) } }
            .sorted { $0.id < $1.id }
    }

    func journey(id: String) -> Journey? { journeys.first { $0.id == id } }
    func journey(style: LetterStyle) -> Journey? { journeys.first { $0.style == style.rawValue } }
}
