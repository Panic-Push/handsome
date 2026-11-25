import Foundation

/// Saves files in the app's Documents folder, which is visible in the
/// Files app under "On My iPad > Penwise".
enum FileStore {
    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    @discardableResult
    static func save(_ data: Data, to relativePath: String) throws -> URL {
        let url = documents.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
        return url
    }

    /// All JSON files under a folder, newest first.
    static func jsonFiles(in folder: String) -> [URL] {
        let root = documents.appendingPathComponent(folder)
        guard let e = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return [] }

        var files: [(URL, Date)] = []
        for case let url as URL in e where url.pathExtension == "json" {
            let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            files.append((url, date))
        }
        return files.sorted { $0.1 > $1.1 }.map { $0.0 }
    }

    static func delete(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
