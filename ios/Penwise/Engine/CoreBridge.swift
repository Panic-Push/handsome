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
