import SwiftUI

@main
struct AwesomeVideoPlayerApp: App {
    @StateObject private var libraryViewModel = LibraryViewModel(
        libraryService: LibraryService()
    )
    @StateObject private var playerViewModel = PlayerViewModel(
        playbackService: PlaybackService()
    )

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(libraryViewModel)
                .environmentObject(playerViewModel)
        }
    }
}

