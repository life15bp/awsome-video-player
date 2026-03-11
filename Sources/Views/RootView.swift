import SwiftUI

struct RootView: View {
    @EnvironmentObject private var libraryViewModel: LibraryViewModel
    @EnvironmentObject private var playerViewModel: PlayerViewModel

    var body: some View {
        NavigationSplitView {
            LibraryView(
                videos: libraryViewModel.videos,
                onVideoDoubleTap: { video in
                    libraryViewModel.selectedVideo = video
                    playerViewModel.load(file: video)
                    playerViewModel.play()
                },
                onAddFolder: { url in
                    libraryViewModel.addFolder(url: url)
                }
            )
        } detail: {
            PlayerView()
        }
    }
}

