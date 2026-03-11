import Foundation

final class LibraryViewModel: ObservableObject {
    @Published private(set) var folders: [URL] = []
    @Published private(set) var videos: [VideoFile] = []
    @Published var selectedVideo: VideoFile?

    private let libraryService: LibraryService

    init(libraryService: LibraryService) {
        self.libraryService = libraryService
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
    }
}

