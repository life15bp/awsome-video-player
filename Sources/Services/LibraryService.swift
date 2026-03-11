import Foundation

final class LibraryService {
    func loadFolders() -> [URL] {
        // 永続化は後で実装
        return []
    }

    func saveFolders(_ folders: [URL]) {
        // 永続化は後で実装
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

