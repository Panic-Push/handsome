import CoreGraphics
import Foundation

/// Swift mirror of the shared template JSON format (see /content/templates).
struct TemplateStroke: Codable, Hashable {
    /// [x, y] pairs in line units, in drawing order.
    var points: [[Double]]

    var cgPoints: [CGPoint] {
        points.compactMap { p in p.count >= 2 ? CGPoint(x: p[0], y: p[1]) : nil }
    }
}

struct LetterTemplate: Codable, Hashable, Identifiable {
    var id: String
    var glyph: String
    var script: String
    var style: String
    var width: Double
    var strokes: [TemplateStroke]
    var alternates: [[TemplateStroke]]?
}

/// Loads the templates bundled with the app from the "templates" folder.
final class TemplateLibrary {
    static let shared = TemplateLibrary()

    let templates: [LetterTemplate]

    /// The original JSON text of each template, keyed by template id.
    /// The shared engine reads templates from this text.
    private let jsonByID: [String: String]

    private init() {
        let loaded = TemplateLibrary.loadBundled()
        templates = loaded.map { $0.template }.sorted { a, b in
            let ra = TemplateLibrary.rank(a.glyph)
            let rb = TemplateLibrary.rank(b.glyph)
            return ra != rb ? ra < rb : a.glyph < b.glyph
        }
        var json: [String: String] = [:]
        for item in loaded { json[item.template.id] = item.json }
        jsonByID = json
    }

    func json(for id: String) -> String? {
        jsonByID[id]
    }

    func template(id: String) -> LetterTemplate? {
        templates.first { $0.id == id }
    }

    /// Letters of one style, in teaching order.
    func templates(style: String) -> [LetterTemplate] {
        templates.filter { $0.style == style }
    }

    func templates(style: LetterStyle) -> [LetterTemplate] {
        templates(style: style.rawValue)
    }

    /// The letter used for worksheet previews on Home.
    func previewTemplate(style: LetterStyle) -> LetterTemplate? {
        let list = templates(style: style)
        return list.first { $0.glyph == "a" } ?? list.first
    }

    /// Teaching order, matching the journey chapters: round letters, tall
    /// letters, tails, bridges, more curves, then diagonals.
    private static let teachingOrder = Array("coadltigqjynmhrbpesfukvwxz")

    private static func rank(_ glyph: String) -> Int {
        guard let first = glyph.first, let index = teachingOrder.firstIndex(of: first) else { return 1_000 }
        return index
    }

    private static func loadBundled() -> [(template: LetterTemplate, json: String)] {
        guard let root = Bundle.main.url(forResource: "templates", withExtension: nil),
              let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        else { return [] }

        let decoder = JSONDecoder()
        var result: [(template: LetterTemplate, json: String)] = []
        for case let url as URL in files where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let text = String(data: data, encoding: .utf8),
                  let template = try? decoder.decode(LetterTemplate.self, from: data)
            else { continue }
            result.append((template: template, json: text))
        }
        return result
    }
}

extension LetterTemplate {
    var isCursive: Bool { style.hasPrefix("cursive") }

    /// Top of the letter in line units (0 = ascender line, 0.5 = x-height).
    var topY: CGFloat {
        strokes.flatMap { $0.cgPoints }.map(\.y).min() ?? 0.5
    }

    /// "lowercase a", "capital A", "cursive a".
    var spokenName: String {
        if style == LetterStyle.traditional.rawValue { return "traditional \(glyph)" }
        if isCursive { return "cursive \(glyph)" }
        if glyph.lowercased() == glyph && glyph.uppercased() != glyph { return "lowercase \(glyph)" }
        if glyph.uppercased() == glyph && glyph.lowercased() != glyph { return "capital \(glyph)" }
        return glyph
    }
}

/// File name for a glyph: its Unicode code points, e.g. "a" -> "0061".
/// Keeps "a" and "A" apart on case-insensitive disks, and works for any script.
func codePointName(_ glyph: String) -> String {
    glyph.unicodeScalars.map { String(format: "%04X", $0.value) }.joined(separator: "_")
}
