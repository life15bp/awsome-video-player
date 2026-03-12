import Foundation

final class FavoriteService {
    private struct PersistedFavorites: Codable {
        var snapshots: [FavoriteSnapshot]
    }

    private let fileManager = FileManager.default

    private var favoritesFileURL: URL? {
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
            return appDirectory.appendingPathComponent("favorites.json")
        } catch {
            return nil
        }
    }

    func loadFavorites() -> [FavoriteSnapshot] {
        guard let url = favoritesFileURL,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(PersistedFavorites.self, from: data)
        else {
            return []
        }
        return decoded.snapshots
    }

    func saveFavorites(_ snapshots: [FavoriteSnapshot]) {
        guard let url = favoritesFileURL else { return }

        let payload = PersistedFavorites(snapshots: snapshots)
        guard let data = try? JSONEncoder().encode(payload) else {
            return
        }

        do {
            try data.write(to: url, options: [.atomic])
        } catch {
            // 永続化失敗時もアプリは動き続ける
        }
    }
}

