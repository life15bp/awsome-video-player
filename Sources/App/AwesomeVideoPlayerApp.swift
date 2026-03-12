import SwiftUI

@main
struct AwesomeVideoPlayerApp: App {
    @StateObject private var libraryViewModel = LibraryViewModel(
        libraryService: LibraryService(),
        thumbnailService: ThumbnailService()
    )
    @StateObject private var playerViewModel = PlayerViewModel(
        playbackService: PlaybackService(),
        favoriteService: FavoriteService()
    )

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(libraryViewModel)
                .environmentObject(playerViewModel)
        }
    }
}

