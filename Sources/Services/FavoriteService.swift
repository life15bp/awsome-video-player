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

    // MARK: - タグ表示順（左ペイン・タグタブ用）

    private var tagOrderFileURL: URL? {
        guard let dir = favoritesFileURL?.deletingLastPathComponent() else { return nil }
        return dir.appendingPathComponent("tag-order.json")
    }

    func loadTagOrder() -> [String] {
        guard let url = tagOrderFileURL,
              let data = try? Data(contentsOf: url),
              let order = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return order
    }

    func saveTagOrder(_ order: [String]) {
        guard let url = tagOrderFileURL,
              let data = try? JSONEncoder().encode(order)
        else { return }
        try? data.write(to: url, options: [.atomic])
    }

    // MARK: - 動画本体のタグ

    private struct VideoTagEntry: Codable {
        let videoId: UUID
        let tags: [String]
    }

    private var videoTagsFileURL: URL? {
        guard let dir = favoritesFileURL?.deletingLastPathComponent() else { return nil }
        return dir.appendingPathComponent("video-tags.json")
    }

    func loadVideoTags() -> [UUID: [String]] {
        guard let url = videoTagsFileURL,
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([VideoTagEntry].self, from: data)
        else { return [:] }
        return Dictionary(uniqueKeysWithValues: entries.map { ($0.videoId, $0.tags) })
    }

    func saveVideoTags(_ map: [UUID: [String]]) {
        guard let url = videoTagsFileURL else { return }
        let entries = map.map { VideoTagEntry(videoId: $0.key, tags: $0.value) }
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: url, options: [.atomic])
    }
}

