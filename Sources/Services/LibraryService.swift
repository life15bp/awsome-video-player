import Foundation
import AppKit

final class LibraryService {
    /// 1フォルダ分の永続化データ（パス + オプションでセキュリティスコープ付きブックマーク）
    private struct PersistedFolderEntry: Codable {
        let path: String
        let bookmarkData: Data?
    }

    /// 旧形式（paths のみ）との互換用
    private struct PersistedFoldersLegacy: Codable {
        let paths: [String]
    }

    private struct PersistedFolders: Codable {
        let items: [PersistedFolderEntry]
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
        guard let fileURL = foldersFileURL,
              let data = try? Data(contentsOf: fileURL) else {
            return []
        }

        // 新形式: items (path + 任意で bookmarkData)
        if let decoded = try? JSONDecoder().decode(PersistedFolders.self, from: data) {
            return decoded.items.compactMap { entry in
                resolveFolderURL(path: entry.path, bookmarkData: entry.bookmarkData)
            }
        }

        // 旧形式: paths のみ
        if let legacy = try? JSONDecoder().decode(PersistedFoldersLegacy.self, from: data) {
            return legacy.paths.compactMap { path in
                let normalized = normalizePathForStorage(path)
                return URL(fileURLWithPath: normalized)
            }
        }

        return []
    }

    /// ブックマークがあれば解決してスコープを取得、なければパスから URL を返す
    private func resolveFolderURL(path: String, bookmarkData: Data?) -> URL? {
        if let data = bookmarkData, !data.isEmpty {
            var isStale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: data,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                if url.startAccessingSecurityScopedResource() {
                    return url
                }
            } catch {
                // 解決に失敗したらパスにフォールバック
            }
        }
        let normalized = normalizePathForStorage(path)
        return URL(fileURLWithPath: normalized)
    }

    /// 保存・比較用にパスを正規化（末尾スラッシュ除去、標準化）
    private func normalizePathForStorage(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        var p = url.standardizedFileURL.path
        if p.hasSuffix("/"), p.count > 1 {
            p = String(p.dropLast())
        }
        return p
    }

    func saveFolders(_ folders: [URL]) {
        guard let url = foldersFileURL else { return }

        let items: [PersistedFolderEntry] = folders.map { folderURL in
            let path = normalizePathForStorage(folderURL.path)
            let bookmarkData: Data? = try? folderURL.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            return PersistedFolderEntry(path: path, bookmarkData: bookmarkData)
        }
        let payload = PersistedFolders(items: items)

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

    /// 指定フォルダとそのサブフォルダ内の全動画をスキャン（ツリー選択用）
    func scanVideosRecursively(in folder: URL, maxDepth: Int = 10) -> [VideoFile] {
        var result: [VideoFile] = []
        var queue: [(url: URL, depth: Int)] = [(folder, 0)]
        while let current = queue.first {
            queue.removeFirst()
            if current.depth > maxDepth { continue }
            result.append(contentsOf: scanVideos(in: current.url))
            for sub in subdirectories(of: current.url) {
                queue.append((sub, current.depth + 1))
            }
        }
        return result
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

    /// 指定フォルダの直下のサブディレクトリ一覧（1階層のみ）
    func subdirectories(of url: URL) -> [URL] {
        guard let items = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return items.compactMap { item in
            guard (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return nil }
            return item
        }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
}

