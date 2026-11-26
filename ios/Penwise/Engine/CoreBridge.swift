import Foundation
import PenwiseCore

// This is the only file that talks to the shared Kotlin engine (PenwiseCore).
// Kotlin types are qualified with `PenwiseCore.` where the app has a type of
// the same name (LetterTemplate).

/// The three learning modes, as shown in the app.
enum WritingMode: String, CaseIterable, Identifiable {
    case learn = "Learn"
    case practice = "Practice"
    case test = "Test"

    var id: String { rawValue }

    var instruction: String {
        switch self {
        case .learn: return "Watch the demo, then trace the dotted letter from the green dot."
        case .practice: return "Write over the faint letter."
        case .test: return "Write the letter from memory."
        }
    }

    fileprivate var core: Mode {
        switch self {
        case .learn: return Mode.learn
        case .practice: return Mode.practice
        case .test: return Mode.test
        }
    }
}

struct ScorePart: Identifiable {
    let name: String
    let value: Int
    var id: String { name }
}

struct ScoreResult {
    let overall: Int
    let parts: [ScorePart]
    /// The single most useful tip, or nil when the letter is good.
    let tip: String?
    let issues: [String]
    /// Issue kinds, most important first, e.g. "OFF_BASELINE".
    let issueKinds: [String]
    /// Template strokes (0-based) to highlight as needing work.
    let problemStrokes: Set<Int>

    /// The kind of the issue the tip is about.
    var primaryKind: String? { issueKinds.first }

    func part(_ name: String) -> Int? {
        parts.first { $0.name == name }?.value
    }
}

enum CoreBridge {
    private static var templateCache: [String: PenwiseCore.LetterTemplate] = [:]
    private static let scorer = LetterScorer()

    static func score(
        strokes: [CapturedStroke],
        templateID: String,
        templateJSON: String,
        mode: WritingMode,
        finger: Bool
    ) throws -> ScoreResult {
        let template: PenwiseCore.LetterTemplate
        if let cached = templateCache[templateID] {
            template = cached
        } else {
            template = try TemplateCodec.shared.decode(text: templateJSON)
            templateCache[templateID] = template
        }

        let ink = Ink(
            strokes: strokes.map { stroke in
                InkStroke(points: stroke.points.map { p in
                    InkPoint(x: p.x, y: p.y, t: p.t, force: p.force)
                })
            },
            input: finger ? InputKind.finger : InputKind.stylus
        )

        let s = scorer.score(ink: ink, template: template, mode: mode.core)

        var parts = [ScorePart(name: "Shape", value: Int(s.shape))]
        let optional: [(String, KotlinInt?)] = [
            ("Order", s.order),
            ("Direction", s.direction),
            ("Start", s.start),
            ("Smoothness", s.smoothness),
            ("Size", s.size),
            ("Baseline", s.baseline),
        ]
        for (name, value) in optional {
            if let value = value {
                parts.append(ScorePart(name: name, value: value.intValue))
            }
        }

        var problems = Set<Int>()
        for issue in s.issues where issue.strokeIndex >= 0 {
            problems.insert(Int(issue.strokeIndex))
        }

        return ScoreResult(
            overall: Int(s.overall),
            parts: parts,
            tip: s.tip,
            issues: s.issues.map { $0.message },
            issueKinds: s.issues.map { $0.kind.name },
            problemStrokes: problems
        )
    }
}

// MARK: - Words and lines

/// A word or line laid out on the writing line by the shared engine.
struct LinePlan {
    fileprivate let placed: [PlacedLetter]
    /// The app's copy of each placed letter's template, in the same order.
    let templates: [LetterTemplate]
    /// Left edge of each letter, in line units.
    let xs: [CGFloat]
    /// Which word each letter belongs to.
    let words: [Int]

    /// Total width in line units.
    var width: CGFloat {
        zip(templates, xs).map { $0.1 + CGFloat($0.0.width) }.max() ?? 0
    }

    var isEmpty: Bool { templates.isEmpty }
}

struct LineResult {
    let overall: Int
    let tip: String?
    let kinds: [String]
    let parts: [ScorePart]
    let words: [(text: String, score: Int)]
    /// Score of each placed letter, in plan order.
    let letterScores: [Int]
    /// Letters the tip is about (missing or worst), in plan order.
    let problemLetters: Set<Int>
}

extension CoreBridge {
    fileprivate static func coreTemplate(id: String) throws -> PenwiseCore.LetterTemplate? {
        if let cached = templateCache[id] { return cached }
        guard let json = TemplateLibrary.shared.json(for: id) else { return nil }
        let template = try TemplateCodec.shared.decode(text: json)
        templateCache[id] = template
        return template
    }

    fileprivate static func makeInk(_ strokes: [CapturedStroke], finger: Bool) -> Ink {
        Ink(
            strokes: strokes.map { stroke in
                InkStroke(points: stroke.points.map { InkPoint(x: $0.x, y: $0.y, t: $0.t, force: $0.force) })
            },
            input: finger ? InputKind.finger : InputKind.stylus
        )
    }

    /// Lays out text in a letter style. Characters without a template
    /// (punctuation) take a little room but are not drawn or scored.
    static func plan(_ text: String, style: LetterStyle) throws -> LinePlan {
        var map: [String: PenwiseCore.LetterTemplate] = [:]
        for glyph in Set(text.map(String.init)) where glyph != " " {
            if let t = try coreTemplate(id: "latin.\(style.rawValue).\(glyph)") { map[glyph] = t }
        }
        let placed = LineLayout.shared.place(text: text, templates: map, cursive: style != .print)
        var templates: [LetterTemplate] = []
        var kept: [PlacedLetter] = []
        for letter in placed {
            guard let t = TemplateLibrary.shared.template(id: "latin.\(style.rawValue).\(letter.letterTemplate.glyph)") else { continue }
            templates.append(t)
            kept.append(letter)
        }
        return LinePlan(placed: kept, templates: templates,
                        xs: kept.map { CGFloat($0.x) }, words: kept.map { Int($0.word) })
    }

    /// Scores a word or line. `traced` means the learner wrote over a model
    /// drawn at the plan's positions; otherwise the writing is free.
    static func scoreLine(strokes: [CapturedStroke], plan: LinePlan, traced: Bool, finger: Bool) -> LineResult {
        let ink = makeInk(strokes, finger: finger)
        let scorer = LineScorer()
        let s = traced ? scorer.scoreTraced(ink: ink, letters: plan.placed) : scorer.scoreFree(ink: ink, letters: plan.placed)
        var parts = [ScorePart(name: "Shape", value: Int(s.shape)),
                     ScorePart(name: "Size", value: Int(s.size)),
                     ScorePart(name: "Baseline", value: Int(s.baseline))]
        if let spacing = s.spacing { parts.append(ScorePart(name: "Spacing", value: spacing.intValue)) }
        if let direction = s.direction { parts.append(ScorePart(name: "Direction", value: direction.intValue)) }
        parts.append(ScorePart(name: "Smoothness", value: Int(s.smoothness)))

        var letterScores = Array(repeating: 0, count: plan.placed.count)
        for word in s.words {
            for letter in word.letters where Int(letter.index) < letterScores.count {
                letterScores[Int(letter.index)] = Int(letter.score)
            }
        }
        var problems = Set<Int>()
        for issue in s.issues where issue.strokeIndex >= 0 { problems.insert(Int(issue.strokeIndex)) }
        return LineResult(
            overall: Int(s.overall),
            tip: s.tip,
            kinds: s.issues.map { $0.kind.name },
            parts: parts,
            words: s.words.map { (text: $0.text, score: Int($0.score)) },
            letterScores: letterScores,
            problemLetters: problems
        )
    }
}
