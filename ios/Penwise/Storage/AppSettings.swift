import Foundation

enum LetterStyle: String, CaseIterable, Identifiable {
    /// Ball-and-stick print, shown as "Normal".
    case print = "print-modern"
    /// Upright joined letters with plain ascenders.
    case cursive = "cursive-modern"
    /// Slanted joined letters with loops.
    case traditional = "cursive-traditional"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .print: return "Normal"
        case .cursive: return "Classic"
        case .traditional: return "Traditional"
        }
    }
}

enum WritingSize: String, CaseIterable, Identifiable {
    case standard
    case large

    var id: String { rawValue }
    var title: String { self == .standard ? "Standard" : "Large" }
}

enum Handedness: String, CaseIterable, Identifiable {
    case right
    case left

    var id: String { rawValue }
    var title: String { self == .right ? "Right hand" : "Left hand" }
}

/// The learner's age band, asked once at first launch. Unknown is treated as
/// a minor for ads (no tracking prompt, ads tagged under the age of consent).
enum AgeBand: String, CaseIterable, Identifiable {
    case unknown
    case under18
    case adult

    var id: String { rawValue }
    var title: String {
        switch self {
        case .unknown: return "Not set"
        case .under18: return "Under 18"
        case .adult: return "18 or older"
        }
    }
}

/// User preferences, saved on this iPad.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var style: LetterStyle { didSet { save(style.rawValue, "style") } }
    @Published var size: WritingSize { didSet { save(size.rawValue, "size") } }
    @Published var handedness: Handedness { didSet { save(handedness.rawValue, "handedness") } }
    @Published var ageBand: AgeBand { didSet { save(ageBand.rawValue, "ageBand") } }
    @Published var pencilOnly: Bool { didSet { defaults.set(pencilOnly, forKey: key("pencilOnly")) } }
    /// Shows ad placeholders until real ads are added (Phase 2). When off,
    /// the app behaves as if no ad is available: the mode screen is skipped.
    @Published var showAdPlaceholders: Bool { didSet { defaults.set(showAdPlaceholders, forKey: key("adPlaceholders")) } }

    private let defaults = UserDefaults.standard

    private init() {
        let d = UserDefaults.standard
        style = LetterStyle(rawValue: d.string(forKey: "penwise.settings.style") ?? "") ?? .print
        size = WritingSize(rawValue: d.string(forKey: "penwise.settings.size") ?? "") ?? .standard
        handedness = Handedness(rawValue: d.string(forKey: "penwise.settings.handedness") ?? "") ?? .right
        ageBand = AgeBand(rawValue: d.string(forKey: "penwise.settings.ageBand") ?? "") ?? .unknown
        pencilOnly = d.object(forKey: "penwise.settings.pencilOnly") as? Bool ?? true
        showAdPlaceholders = d.object(forKey: "penwise.settings.adPlaceholders") as? Bool ?? false
    }

    private func key(_ name: String) -> String { "penwise.settings.\(name)" }

    private func save(_ value: String, _ name: String) {
        defaults.set(value, forKey: key(name))
    }
}
