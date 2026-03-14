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
        WindowGroup("Library") {
            RootView()
                .environmentObject(libraryViewModel)
                .environmentObject(playerViewModel)
        }

        Window("Player", id: "playerWindow") {
            PlayerView()
                .environmentObject(libraryViewModel)
                .environmentObject(playerViewModel)
        }
        .commands {
            CommandMenu("Playback") {
                Button {
                    playerViewModel.togglePlayPause()
                } label: {
                    Text("再生 / 一時停止")
                }
                .keyboardShortcut(.space, modifiers: [])

                Button {
                    playerViewModel.addFavoriteAtCurrentTime()
                } label: {
                    Text("お気に入りに追加")
                }
                .keyboardShortcut("d", modifiers: [.command])
            }
        }
    }
}

