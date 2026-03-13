import SwiftUI

struct RootView: View {
    @EnvironmentObject private var libraryViewModel: LibraryViewModel
    @EnvironmentObject private var playerViewModel: PlayerViewModel

    var body: some View {
        NavigationSplitView {
            LibraryView(onAddFolder: { url in
                libraryViewModel.addFolder(url: url)
            })
        } detail: {
            VideoListDetailView()
        }
    }
}

