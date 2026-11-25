import SwiftUI
import UIKit

/// Milestone 2: record letter templates and handwriting samples as JSON.
///
/// Templates go to Documents/templates/<script>/<style>/<code points>.json and
/// samples to Documents/samples/. Both are visible in the Files app and can be
/// shared, so they can be added to the repository's /content folder.
struct RecorderView: View {
    enum Kind: String, CaseIterable, Identifiable {
        case template = "Template"
        case sample = "Sample"
        var id: String { rawValue }
    }

    @StateObject private var ink = InkModel()
    @State private var kind: Kind = .template
    @State private var glyph = "a"
    @State private var style = "print-modern"
    @State private var canvasSize: CGSize = .zero
    @State private var savedFiles: [URL] = []
    @State private var message: String?

    /// Wide letter box so any letter fits; x is re-zeroed when saving a template.
    private let letterBox: CGFloat = 1.2

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            GeometryReader { geo in
                ZStack {
                    Color(uiColor: .systemBackground)
                    RuledLinesView(layout: GuideLayout.fit(in: geo.size, letterWidth: letterBox))
                    InkCanvas(model: ink)
                }
                .onAppear { canvasSize = geo.size }
                .onChange(of: geo.size) { _, newSize in
                    canvasSize = newSize
                    ink.clear()
                }
            }
            Divider()
            savedList
        }
        .navigationTitle("Recorder")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refresh)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Picker("Type", selection: $kind) {
                    ForEach(Kind.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)

                TextField("Letter", text: $glyph)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .frame(width: 90)

                if kind == .template {
                    TextField("Style", text: $style)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .frame(width: 160)
                }

                Toggle("Pencil only", isOn: $ink.pencilOnly)
                    .fixedSize()

                Spacer()

                Button { ink.undo() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                    .disabled(ink.strokeCount == 0)
                Button(role: .destructive) { ink.clear() } label: { Label("Clear", systemImage: "trash") }
                    .disabled(ink.strokeCount == 0)
                Button("Save", action: save)
                    .buttonStyle(.borderedProminent)
                    .disabled(ink.strokeCount == 0 || glyph.isEmpty)
            }
            Text(message ?? hint)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }

    private var hint: String {
        switch kind {
        case .template:
            return "Write the letter neatly, strokes in the correct order. It becomes the reference others are scored against."
        case .sample:
            return "Write the letter naturally. Samples are used to test and tune the scoring engine."
        }
    }

    private var savedList: some View {
        List {
            Section("Saved files (also in the Files app: On My iPad › Penwise)") {
                if savedFiles.isEmpty {
                    Text("Nothing saved yet").foregroundStyle(.secondary)
                }
                ForEach(savedFiles, id: \.self) { url in
                    HStack {
                        Text(displayName(url)).font(.callout.monospaced())
                        Spacer()
                        ShareLink(item: url) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                }
                .onDelete { offsets in
                    for i in offsets { FileStore.delete(savedFiles[i]) }
                    refresh()
                }
            }
        }
        .listStyle(.insetGrouped)
        .frame(height: 220)
    }

    private func displayName(_ url: URL) -> String {
        let docs = FileStore.documents.path
        return url.path.replacingOccurrences(of: docs + "/", with: "")
    }

    private func refresh() {
        savedFiles = FileStore.jsonFiles(in: "templates") + FileStore.jsonFiles(in: "samples")
    }

    private func save() {
        let layout = GuideLayout.fit(in: canvasSize, letterWidth: letterBox)
        let strokes = ink.capturedStrokes(in: layout)
        let name = glyph.trimmingCharacters(in: .whitespaces)
        do {
            let url: URL
            switch kind {
            case .template:
                url = try RecorderExport.saveTemplate(strokes: strokes, glyph: name, style: style)
            case .sample:
                url = try RecorderExport.saveSample(strokes: strokes, glyph: name, finger: ink.lastInkUsedFinger)
            }
            message = "Saved \(displayName(url))"
            ink.clear()
            refresh()
        } catch {
            message = "Could not save: \(error.localizedDescription)"
        }
    }
}

enum RecorderExport {
    enum ExportError: LocalizedError {
        case empty
        var errorDescription: String? { "Nothing was written." }
    }

    private struct TemplateFile: Encodable {
        var id: String
        var glyph: String
        var script: String
        var style: String
        var width: Double
        var strokes: [TemplateStroke]
    }

    /// Same shape as the shared core's Ink JSON, plus a few extra fields.
    private struct SampleFile: Encodable {
        var glyph: String
        var input: String
        var createdAt: String
        var device: String
        var strokes: [CapturedStroke]
    }

    static func saveTemplate(strokes: [CapturedStroke], glyph: String, style: String) throws -> URL {
        let all = strokes.flatMap { $0.points }
        guard let minX = all.map(\.x).min(), let maxX = all.map(\.x).max() else { throw ExportError.empty }

        let simplified = strokes.map { stroke -> TemplateStroke in
            let points = stroke.points.map { CGPoint(x: $0.x - minX, y: $0.y) }
            let even = PathMath.resample(points, spacing: 0.02)
            return TemplateStroke(points: even.map { [round4(Double($0.x)), round4(Double($0.y))] })
        }
        let file = TemplateFile(
            id: "latin.\(style).\(glyph)",
            glyph: glyph,
            script: "latin",
            style: style,
            width: round4(max(maxX - minX, 0.1)),
            strokes: simplified
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try FileStore.save(
            try encoder.encode(file),
            to: "templates/latin/\(style)/\(codePointName(glyph)).json"
        )
    }

    static func saveSample(strokes: [CapturedStroke], glyph: String, finger: Bool) throws -> URL {
        guard !strokes.isEmpty else { throw ExportError.empty }
        let now = Date()
        let file = SampleFile(
            glyph: glyph,
            input: finger ? "FINGER" : "STYLUS",
            createdAt: ISO8601DateFormatter().string(from: now),
            device: UIDevice.current.model,
            strokes: strokes
        )
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyyMMdd-HHmmss"
        stamp.locale = Locale(identifier: "en_US_POSIX")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try FileStore.save(
            try encoder.encode(file),
            to: "samples/\(codePointName(glyph))-\(stamp.string(from: now)).json"
        )
    }

    private static func round4(_ v: Double) -> Double {
        (v * 10_000).rounded() / 10_000
    }
}
