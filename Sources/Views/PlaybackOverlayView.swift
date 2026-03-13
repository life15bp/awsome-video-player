import SwiftUI
import AppKit

struct PlaybackOverlayView: View {
    @EnvironmentObject private var libraryViewModel: LibraryViewModel
    @EnvironmentObject private var playerViewModel: PlayerViewModel

    // お気に入りサムネイルの見た目サイズ（16:9）
    private let favoriteThumbnailSize = CGSize(width: 240, height: 135)

    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                favoritesBar
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .allowsHitTesting(true)
    }

    private var favoritesBar: some View {
        HStack(spacing: 8) {
            if playerViewModel.favoritesForCurrentFile.isEmpty {
                EmptyView()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(playerViewModel.favoritesForCurrentFile) { snapshot in
                            if let video = video(for: snapshot.videoId) {
                                FavoriteSnapshotThumbnailView(
                                    video: video,
                                    snapshot: snapshot,
                                    size: favoriteThumbnailSize
                                )
                                .onTapGesture {
                                    playerViewModel.seek(to: snapshot)
                                }
                            }
                        }
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.5))
                )
            }
        }
        .padding([.top, .leading, .trailing], 12)
    }

    private func video(for id: UUID) -> VideoFile? {
        libraryViewModel.videos.first { $0.id == id }
    }
}

