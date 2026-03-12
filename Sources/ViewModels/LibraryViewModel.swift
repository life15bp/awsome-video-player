import Foundation
import AppKit

final class LibraryViewModel: ObservableObject {
    @Published private(set) var folders: [URL] = []
    @Published private(set) var videos: [VideoFile] = []
    @Published var selectedVideo: VideoFile?
    @Published private(set) var thumbnails: [UUID: NSImage] = [:]

    private let libraryService: LibraryService
    private let thumbnailService: ThumbnailService

    init(libraryService: LibraryService, thumbnailService: ThumbnailService) {
        self.libraryService = libraryService
        self.thumbnailService = thumbnailService
        self.folders = libraryService.loadFolders()
        refreshAllVideos()
    }

    func addFolder(url: URL) {
        guard !folders.contains(url) else { return }
        folders.append(url)
        libraryService.saveFolders(folders)
        refreshAllVideos()
    }

    func refreshAllVideos() {
        videos = folders.flatMap { libraryService.scanVideos(in: $0) }
        thumbnails = [:]
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


