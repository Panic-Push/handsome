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

    private init() {
        templates = TemplateLibrary.loadBundled()
    }

    private static func loadBundled() -> [LetterTemplate] {
        guard let root = Bundle.main.url(forResource: "templates", withExtension: nil),
              let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        else { return [] }

        let decoder = JSONDecoder()
        var result: [LetterTemplate] = []
        for case let url as URL in files where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let template = try? decoder.decode(LetterTemplate.self, from: data)
            else { continue }
            result.append(template)
        }
        return result.sorted { $0.glyph < $1.glyph }
    }
}

/// File name for a glyph: its Unicode code points, e.g. "a" -> "0061".
/// Keeps "a" and "A" apart on case-insensitive disks, and works for any script.
func codePointName(_ glyph: String) -> String {
    glyph.unicodeScalars.map { String(format: "%04X", $0.value) }.joined(separator: "_")
}
