import SwiftUI
import AppKit

struct PlaybackOverlayView: View {
    @EnvironmentObject private var libraryViewModel: LibraryViewModel
    @EnvironmentObject private var playerViewModel: PlayerViewModel
    @State private var isTopHovered = false

    // お気に入りサムネイルの見た目サイズ（16:9）
    private let favoriteThumbnailSize = CGSize(width: 240, height: 135)
    /// 上部ホバーで表示するトリガー領域の高さ（マウスがここに入るとバー表示）
    private let topHoverZoneHeight: CGFloat = 44
    /// バー表示時のホバー維持用の高さ（トリガー＋バー領域。ここにいる間はバーを表示したまま）
    private let hoverZoneWithBarHeight: CGFloat = 200

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    favoritesBar
                        .opacity(isTopHovered ? 1 : 0)
                        .animation(.easeInOut(duration: 0.2), value: isTopHovered)
                        .allowsHitTesting(isTopHovered)
                    Color.clear
                        .frame(height: isTopHovered ? hoverZoneWithBarHeight : topHoverZoneHeight)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onHover { isTopHovered = $0 }
                }
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
                                    size: favoriteThumbnailSize,
                                    onDelete: { playerViewModel.removeFavorite(snapshot) }
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

