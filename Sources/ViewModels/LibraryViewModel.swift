import Foundation
import AppKit
import Combine

/// 左ペインのタブ種別
enum LeftPaneTab: String, CaseIterable {
    case folder = "フォルダ"
    case tag = "タグ"
}

final class LibraryViewModel: ObservableObject {
    @Published private(set) var folders: [URL] = []
    @Published private(set) var videos: [VideoFile] = []
    @Published var selectedVideo: VideoFile?
    @Published var selectedFolder: URL?
    @Published private(set) var folderTree: [FolderNode] = []
    /// 左ペインでフォルダ／タグのどちらを表示するか
    @Published var leftPaneTab: LeftPaneTab = .folder
    /// タグタブで選択中のフィルタ。nil = 「お気に入り」（お気に入りが1つ以上ある動画）、非nil = そのタグが付いた動画
    @Published var selectedTagForFilter: String? = nil

    private let libraryService: LibraryService
    private let thumbnailService: ThumbnailService
    private let folderTreeMaxDepth = 4

    init(libraryService: LibraryService, thumbnailService: ThumbnailService) {
        self.libraryService = libraryService
        self.thumbnailService = thumbnailService
        self.folders = libraryService.loadFolders()
        self.selectedFolder = folders.first
        refreshAllVideos()
    }

    func addFolder(url: URL) {
        let normalized = url.standardizedFileURL
        guard !folders.contains(where: { $0.standardizedFileURL.path.trimmingTrailingSlash() == normalized.path.trimmingTrailingSlash() }) else { return }
        folders.append(normalized)
        libraryService.saveFolders(folders)
        selectedFolder = normalized
        refreshAllVideos()
    }

    /// 追加したルートフォルダかどうか（削除対象になるのはルートのみ）
    func isRootFolder(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path.trimmingTrailingSlash()
        return folders.contains { $0.standardizedFileURL.path.trimmingTrailingSlash() == path }
    }

    /// ライブラリからフォルダを削除（ルートフォルダのみ。ディスクには残る）
    func removeFolder(_ url: URL) {
        let path = url.standardizedFileURL.path.trimmingTrailingSlash()
        folders.removeAll { $0.standardizedFileURL.path.trimmingTrailingSlash() == path }
        libraryService.saveFolders(folders)
        if selectedFolder?.standardizedFileURL.path.trimmingTrailingSlash() == path {
            selectedFolder = folders.first
        }
        refreshAllVideos()
    }

    /// フォルダをゴミ箱へ移動する（子フォルダ用。中身ごとゴミ箱へ）
    /// - Returns: 成功したら true
    func deleteFolder(at url: URL) -> Bool {
        let standardized = url.standardizedFileURL
        do {
            try FileManager.default.trashItem(at: standardized, resultingItemURL: nil)
            let deletedPath = standardized.path.trimmingTrailingSlash()
            if selectedFolder?.standardizedFileURL.path.trimmingTrailingSlash() == deletedPath
                || selectedFolder?.standardizedFileURL.path.hasPrefix(deletedPath + "/") == true {
                selectedFolder = folders.first
            }
            refreshAllVideos()
            return true
        } catch {
            return false
        }
    }

    /// 追加したフォルダの並び順を変更する（ルートのみ、D&D 並べ替え用）
    func reorderFolders(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
              sourceIndex >= 0, sourceIndex < folders.count,
              destinationIndex >= 0, destinationIndex <= folders.count else { return }
        var newFolders = folders
        let item = newFolders.remove(at: sourceIndex)
        let insertIndex = min(destinationIndex, newFolders.count)
        newFolders.insert(item, at: insertIndex)
        folders = newFolders
        libraryService.saveFolders(folders)
        refreshAllVideos()
    }

    /// ID で動画を取得（D&D のドロップ時に使用）
    func video(byId id: UUID) -> VideoFile? {
        videos.first { $0.id == id }
    }

    /// 動画を指定フォルダへ移動。お気に入り・タグは identity で保持される。
    /// - Returns: 成功したら true
    func moveVideo(_ video: VideoFile, to folderURL: URL) -> Bool {
        guard libraryService.moveVideo(video, toDestinationFolder: folderURL) else { return false }
        refreshAllVideos()
        return true
    }

    /// 動画ファイルをゴミ箱へ移動する。
    /// - Returns: 成功したら true
    func deleteVideo(_ video: VideoFile) -> Bool {
        do {
            try FileManager.default.trashItem(at: video.url, resultingItemURL: nil)
            refreshAllVideos()
            return true
        } catch {
            return false
        }
    }

    /// 動画ファイルのファイル名を変更する。
    /// - Parameter newName: 新しいファイル名（拡張子を含む）
    /// - Returns: 成功したら true
    func renameVideo(_ video: VideoFile, to newName: String) -> Bool {
        guard libraryService.renameVideo(video, to: newName) else { return false }
        refreshAllVideos()
        return true
    }

    /// フォルダ名を変更する。ルートの場合は保存済みフォルダ一覧も更新する。
    /// - Returns: 成功時は (true, nil)、失敗時は (false, 表示用エラー文言)
    func renameFolder(at url: URL, to newName: String) -> (success: Bool, errorMessage: String?) {
        let result = libraryService.renameFolder(at: url, to: newName)
        guard result.success else { return result }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let newURL = url.deletingLastPathComponent().appendingPathComponent(trimmed).standardizedFileURL
        let oldPath = url.standardizedFileURL.path.trimmingTrailingSlash()
        let newPath = newURL.path.trimmingTrailingSlash()

        if isRootFolder(url) {
            if let i = folders.firstIndex(where: { $0.standardizedFileURL.path.trimmingTrailingSlash() == oldPath }) {
                folders[i] = newURL
                libraryService.saveFolders(folders)
            }
        }

        if let sel = selectedFolder {
            let selPath = sel.standardizedFileURL.path.trimmingTrailingSlash()
            if selPath == oldPath {
                selectedFolder = newURL
            } else if selPath.hasPrefix(oldPath + "/") {
                let suffix = String(selPath.dropFirst(oldPath.count))
                selectedFolder = URL(fileURLWithPath: newPath + suffix)
            }
        }
        refreshAllVideos()
        return (true, nil)
    }

    /// 指定フォルダの直下に子フォルダを新規作成する。作成後にツリーを再構築する。
    /// - Returns: 成功時は (true, nil)、失敗時は (false, 表示用エラー文言)
    func createSubfolder(name: String, under parentURL: URL) -> (success: Bool, errorMessage: String?) {
        let result = libraryService.createSubfolder(name: name, under: parentURL)
        if result.success {
            refreshAllVideos()
        }
        return result
    }

    func refreshAllVideos() {
        videos = folders.flatMap { libraryService.scanVideosRecursively(in: $0) }
        _thumbnailsByKey = [:]
        folderTree = folders.map { buildFolderNode(url: $0, depth: 0) }
    }

    private func buildFolderNode(url: URL, depth: Int) -> FolderNode {
        guard depth < folderTreeMaxDepth else {
            return FolderNode(url: url)
        }
        let subdirs = libraryService.subdirectories(of: url)
        let children = subdirs.map { buildFolderNode(url: $0, depth: depth + 1) }
        return FolderNode(url: url, children: children)
    }

    var videosInSelectedFolder: [VideoFile] {
        guard let selectedFolder else {
            return videos
        }
        let selectedPath = selectedFolder.standardizedFileURL.path.trimmingTrailingSlash()
        return videos.filter {
            $0.url.deletingLastPathComponent().standardizedFileURL.path.trimmingTrailingSlash() == selectedPath
        }
    }

    func videosInSameFolder(as video: VideoFile) -> [VideoFile] {
        let folder = video.url.deletingLastPathComponent()
        return videos.filter { $0.url.deletingLastPathComponent() == folder }
    }

    /// Retina 用に要求サイズをスケール（メインサムネイルの画質を他と揃える）
    private static var thumbnailScale: CGFloat {
        NSScreen.main?.backingScaleFactor ?? 2
    }

    /// 動画のサムネイル。preferredTime を指定するとその時刻のフレームを使用（お気に入り中のお気に入り用）
    func thumbnail(for video: VideoFile, at preferredTime: Double? = nil, targetSize: CGSize = .init(width: 320, height: 180)) -> NSImage? {
        let timeKey = preferredTime.map { String(format: "%.3f", $0) } ?? "0"
        let cacheKey = "\(video.id.uuidString)#\(timeKey)"
        if let image = thumbnailsByKey[cacheKey] {
            return image
        }

        let pixelSize = CGSize(
            width: targetSize.width * Self.thumbnailScale,
            height: targetSize.height * Self.thumbnailScale
        )
        thumbnailService.thumbnail(for: video.url, at: preferredTime ?? 0, targetSize: pixelSize) { [weak self] image in
            guard let self, let image else { return }
            self.thumbnailsByKey[cacheKey] = image
            self.objectWillChange.send()
        }

        return nil
    }

    /// サムネイルキャッシュ（videoId#時刻 をキーに統一）
    private var thumbnailsByKey: [String: NSImage] {
        get { _thumbnailsByKey }
        set { _thumbnailsByKey = newValue }
    }
    @Published private var _thumbnailsByKey: [String: NSImage] = [:]
}

private extension String {
    func trimmingTrailingSlash() -> String {
        if hasSuffix("/"), count > 1 { return String(dropLast()) }
        return self
    }
}


