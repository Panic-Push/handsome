import Foundation

enum LetterStyle: String, CaseIterable, Identifiable {
    case print = "print-modern"
    case cursive = "cursive-modern"

    var id: String { rawValue }
    var title: String { self == .print ? "Print" : "Cursive" }
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

/// User preferences, saved on this iPad.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var style: LetterStyle { didSet { save(style.rawValue, "style") } }
    @Published var size: WritingSize { didSet { save(size.rawValue, "size") } }
    @Published var handedness: Handedness { didSet { save(handedness.rawValue, "handedness") } }
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
        pencilOnly = d.object(forKey: "penwise.settings.pencilOnly") as? Bool ?? true
        showAdPlaceholders = d.object(forKey: "penwise.settings.adPlaceholders") as? Bool ?? true
    }

    private func key(_ name: String) -> String { "penwise.settings.\(name)" }

    private func save(_ value: String, _ name: String) {
        defaults.set(value, forKey: key(name))
    }
}
