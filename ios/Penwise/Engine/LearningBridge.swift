import Foundation
import PenwiseCore

// Swift-friendly wrappers around the engine's assessment, plan and word bank.
// Everything here returns plain Swift values that can be saved and shown.

/// One task of the starting assessment.
struct AssessmentTaskInfo: Identifiable, Hashable {
    let id: String
    /// A single letter, or a word/sentence when `isLine` is true.
    let text: String
    let isLine: Bool
    let prompt: String
}

/// The result of the starting assessment, saved on the device.
struct HandwritingReport: Codable, Equatable {
    struct SkillLevel: Codable, Equatable, Identifiable {
        /// Engine name, e.g. "BASELINE".
        let skill: String
        let title: String
        let advice: String
        let score: Int
        var id: String { skill }
    }

    struct LetterLevel: Codable, Equatable, Identifiable {
        let glyph: String
        let score: Int
        var id: String { glyph }
    }

    let date: Date
    /// The letter style the assessment was written in (LetterStyle raw value).
    let style: String
    let overall: Int
    /// Every measured skill, weakest first.
    let skills: [SkillLevel]
    /// Up to three skill names to work on, weakest first.
    let focus: [String]
    /// Skill names at 85 or above.
    let strengths: [String]
    let letters: [LetterLevel]
    /// Letters that scored below 70, weakest first.
    let weakLetters: [String]
    let lettersPerMinute: Int?
    let summary: String

    func title(of skill: String) -> String {
        skills.first { $0.skill == skill }?.title ?? skill.capitalized
    }

    var focusTitles: [String] { focus.map(title(of:)) }
    var strengthTitles: [String] { strengths.map(title(of:)) }
}

/// What a plan item opens.
enum PlanActivityKind: String, Codable {
    case letterLesson = "LETTER_LESSON"
    case letterPractice = "LETTER_PRACTICE"
    case letterTest = "LETTER_TEST"
    case words = "WORDS"
    case sentence = "SENTENCE"
}

struct PlanItem: Codable, Equatable, Hashable, Identifiable {
    let id: String
    let kind: PlanActivityKind
    let title: String
    let detail: String
    let letters: [String]
    let minutes: Int
    /// Skill to emphasise (e.g. "BASELINE"), or nil.
    let focus: String?
}

struct PlanDay: Codable, Equatable {
    let day: Int
    let minutes: Int
    let focus: [String]
    let items: [PlanItem]
    let reassessAfterDays: Int
}

/// Collects the assessment's scored tasks in the engine and builds the report.
final class AssessmentRecorder {
    private let builder = AssessmentReportBuilder()

    /// Scores a single letter written from memory and adds it. Returns the score.
    @discardableResult
    func addLetter(_ glyph: String, strokes: [CapturedStroke], style: LetterStyle, finger: Bool) throws -> Int {
        guard let template = try CoreBridge.coreTemplate(id: "latin.\(style.rawValue).\(glyph)") else { return 0 }
        let score = LetterScorer().score(ink: CoreBridge.makeInk(strokes, finger: finger), template: template, mode: Mode.test)
        builder.addLetter(glyph: glyph, score: score)
        return Int(score.overall)
    }

    /// Scores a word or sentence written freely and adds it. `seconds` is the
    /// time from first touch to last lift (negative if unknown).
    @discardableResult
    func addLine(_ text: String, plan: LinePlan, strokes: [CapturedStroke], seconds: Double, finger: Bool) -> Int {
        let score = LineScorer().scoreFree(ink: CoreBridge.makeInk(strokes, finger: finger), letters: plan.placed)
        builder.addLine(text: text, score: score, seconds: seconds)
        return Int(score.overall)
    }

    func report(style: LetterStyle) -> HandwritingReport {
        let r = builder.build()
        return HandwritingReport(
            date: Date(),
            style: style.rawValue,
            overall: Int(r.overall),
            skills: r.skills.map {
                HandwritingReport.SkillLevel(skill: $0.skill.name, title: $0.skill.title,
                                             advice: $0.skill.advice, score: Int($0.score))
            },
            focus: r.focus.map { $0.name },
            strengths: r.strengths.map { $0.name },
            letters: r.letters.map { HandwritingReport.LetterLevel(glyph: $0.glyph, score: Int($0.score)) },
            weakLetters: r.weakLetters,
            lettersPerMinute: r.lettersPerMinute.map { $0.intValue },
            summary: r.summary
        )
    }
}

enum LearningBridge {
    static var assessmentTasks: [AssessmentTaskInfo] {
        AssessmentPlan.shared.tasks.map {
            AssessmentTaskInfo(id: $0.key, text: $0.text, isLine: $0.isLine, prompt: $0.prompt)
        }
    }

    /// The plan for a given day (0 = the day of the assessment).
    static func plan(for report: HandwritingReport, minutes: Int, day: Int) -> PlanDay {
        let p = PlanBuilder.shared.buildFor(
            overall: Int32(report.overall),
            focusSkills: report.focus,
            weakLetters: report.weakLetters,
            minutesPerDay: Int32(minutes),
            day: Int32(day)
        )
        return PlanDay(
            day: Int(p.day),
            minutes: Int(p.minutes),
            focus: p.focus.map { $0.name },
            items: p.activities.map {
                PlanItem(id: $0.key, kind: PlanActivityKind(rawValue: $0.kind.name) ?? .letterPractice,
                         title: $0.title, detail: $0.detail, letters: $0.letters,
                         minutes: Int($0.minutes), focus: $0.focus?.name)
            },
            reassessAfterDays: Int(p.reassessAfterDays)
        )
    }

    private static let wordBank: WordBank? = {
        guard let url = Bundle.main.url(forResource: "en", withExtension: "json", subdirectory: "words"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return try? WordBank.companion.fromJson(text: text)
    }()

    /// Practice words containing the focus letters; with `allowed`, only
    /// words made of those letters.
    static func words(focus: [String], allowed: [String]?, count: Int, seed: Int,
                      minLength: Int = 3, maxLength: Int = 6) -> [String] {
        wordBank?.pick(focus: focus, allowed: allowed, count: Int32(count), seed: Int32(seed),
                       minLength: Int32(minLength), maxLength: Int32(maxLength)) ?? []
    }
}
