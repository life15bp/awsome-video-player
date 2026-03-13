import Foundation
import AppKit
import Combine

final class LibraryViewModel: ObservableObject {
    @Published private(set) var folders: [URL] = []
    @Published private(set) var videos: [VideoFile] = []
    @Published var selectedVideo: VideoFile?
    @Published var selectedFolder: URL?
    @Published private(set) var thumbnails: [UUID: NSImage] = [:]
    @Published private(set) var folderTree: [FolderNode] = []

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

    /// ライブラリからフォルダを削除（ルートフォルダのみ）
    func removeFolder(_ url: URL) {
        let path = url.standardizedFileURL.path.trimmingTrailingSlash()
        folders.removeAll { $0.standardizedFileURL.path.trimmingTrailingSlash() == path }
        libraryService.saveFolders(folders)
        if selectedFolder?.standardizedFileURL.path.trimmingTrailingSlash() == path {
            selectedFolder = folders.first
        }
        refreshAllVideos()
    }

    func refreshAllVideos() {
        videos = folders.flatMap { libraryService.scanVideosRecursively(in: $0) }
        thumbnails = [:]
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

    func thumbnail(for video: VideoFile, targetSize: CGSize = .init(width: 320, height: 180)) -> NSImage? {
        if let image = thumbnails[video.id] {
            return image
        }

        thumbnailService.thumbnail(for: video.url, targetSize: targetSize) { [weak self] image in
            guard let self, let image else { return }
            self.thumbnails[video.id] = image
        }

        return nil
    }
}

private extension String {
    func trimmingTrailingSlash() -> String {
        if hasSuffix("/"), count > 1 { return String(dropLast()) }
        return self
    }
}


