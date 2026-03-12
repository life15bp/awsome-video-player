import Foundation

final class LibraryService {
    private struct PersistedFolders: Codable {
        let paths: [String]
    }

    private struct VideoIdentityRecord: Codable {
        let id: UUID
        /// fileIdentifier が取れる場合はその値、それ以外はパスをキーとして使う
        let key: String
    }

    private let fileManager = FileManager.default
    private var videoIdentities: [String: UUID] = [:]

    private var identitiesFileURL: URL? {
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
            return appDirectory.appendingPathComponent("video-identities.json")
        } catch {
            return nil
        }
    }

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

    init() {
        loadVideoIdentities()
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

    private func loadVideoIdentities() {
        guard let url = identitiesFileURL,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([VideoIdentityRecord].self, from: data)
        else {
            videoIdentities = [:]
            return
        }

        videoIdentities = Dictionary(uniqueKeysWithValues: decoded.map { ($0.key, $0.id) })
    }

    private func saveVideoIdentities() {
        guard let url = identitiesFileURL else { return }
        let records = videoIdentities.map { VideoIdentityRecord(id: $0.value, key: $0.key) }

        guard let data = try? JSONEncoder().encode(records) else { return }

        do {
            try data.write(to: url, options: [.atomic])
        } catch {
            // 永続化に失敗してもアプリ自体は動作させたいので握りつぶす
        }
    }

    /// URL から「ファイル固有ID or パス」を元にした安定キーを生成する
    private func identityKey(for url: URL) -> String {
        if let values = try? url.resourceValues(forKeys: [.fileResourceIdentifierKey]),
           let identifier = values.fileResourceIdentifier {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: identifier, requiringSecureCoding: true) {
                return "fid:" + data.base64EncodedString()
            }
        }
        return "path:" + url.path
    }

    func scanVideos(in folder: URL) -> [VideoFile] {
        let fileManager = FileManager.default
        guard let items = try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else {
            return []
        }

        let videoExtensions: Set<String> = ["mp4", "mov", "m4v", "mkv"]

        var didUpdateIdentities = false

        let videos: [VideoFile] = items
            .filter { videoExtensions.contains($0.pathExtension.lowercased()) }
            .map { url in
                let key = identityKey(for: url)
                let id: UUID
                if let existing = videoIdentities[key] {
                    id = existing
                } else if let legacy = videoIdentities[url.path] {
                    // 以前の「パスのみ」方式からの移行用
                    id = legacy
                    videoIdentities.removeValue(forKey: url.path)
                    videoIdentities[key] = legacy
                    didUpdateIdentities = true
                } else {
                    id = UUID()
                    videoIdentities[key] = id
                    didUpdateIdentities = true
                }
                return VideoFile(id: id, url: url)
            }

        if didUpdateIdentities {
            saveVideoIdentities()
        }

        return videos
    }
}

