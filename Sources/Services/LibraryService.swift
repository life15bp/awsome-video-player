import Foundation

final class LibraryService {
    private struct PersistedFolders: Codable {
        let paths: [String]
    }

    private let fileManager = FileManager.default

    private var foldersFileURL: URL? {
        do {
            let appSupport = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let appDirectory = appSupport.appendingPathComponent("AwesomeVideoPlayer", isDirectory: true)
            if !fileManager.fileExists(atPath: appDirectory.path) {
                try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
            }
            return appDirectory.appendingPathComponent("folders.json")
        } catch {
            return nil
        }
    }

    func loadFolders() -> [URL] {
        guard let url = foldersFileURL,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(PersistedFolders.self, from: data)
        else {
            return []
        }

        return decoded.paths.compactMap { path in
            URL(fileURLWithPath: path)
        }
    }

    func saveFolders(_ folders: [URL]) {
        guard let url = foldersFileURL else { return }

        let paths = folders.map { $0.path }
        let payload = PersistedFolders(paths: paths)

        guard let data = try? JSONEncoder().encode(payload) else {
            return
        }

        do {
            try data.write(to: url, options: [.atomic])
        } catch {
            // 永続化に失敗してもアプリ自体は動作させたいので握りつぶす
        }
    }

    func scanVideos(in folder: URL) -> [VideoFile] {
        let fileManager = FileManager.default
        guard let items = try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else {
            return []
        }

        let videoExtensions: Set<String> = ["mp4", "mov", "m4v", "mkv"]

        return items
            .filter { videoExtensions.contains($0.pathExtension.lowercased()) }
            .map { VideoFile(url: $0) }
    }
}

