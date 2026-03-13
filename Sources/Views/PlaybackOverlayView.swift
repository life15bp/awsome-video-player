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

            VStack {
                Spacer()
                folderFavoritesPanel
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
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

    /// そのフォルダ内の全動画のお気に入りサムネイルを横並び（添付イメージに近い形）
    private var folderFavoritesPanel: some View {
        Group {
            if let current = playerViewModel.currentFile {
                let folderFavorites = folderFavoritesList(current: current)
                VStack(alignment: .leading, spacing: 4) {
                    Text("お気に入り")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.top, 6)

                    if folderFavorites.isEmpty {
                        Text("このフォルダにお気に入りはありません")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(8)
                    } else {
                        ScrollView(.vertical, showsIndicators: true) {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(folderFavorites, id: \.snapshot.id) { item in
                                    if let video = libraryViewModel.videos.first(where: { $0.id == item.snapshot.videoId }) {
                                        FavoriteSnapshotThumbnailView(
                                            video: video,
                                            snapshot: item.snapshot,
                                            size: favoriteThumbnailSize
                                        )
                                        .onTapGesture {
                                            playerViewModel.playSnapshot(item.snapshot, video: video)
                                        }
                                    }
                                }
                            }
                            .padding(.bottom, 6)
                        }
                    }
                }
                .frame(width: 260, height: 320)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.6))
                )
                .padding([.trailing, .bottom], 12)
            }
        }
    }

    /// 現在動画と同じフォルダに属する動画たちのお気に入りスナップショット一覧（動画ごとに時系列で並べたもの）
    private func folderFavoritesList(current: VideoFile) -> [(snapshot: FavoriteSnapshot, video: VideoFile)] {
        let videosInFolder = libraryViewModel.videosInSameFolder(as: current)
        let videoIds = Set(videosInFolder.map(\.id))
        return playerViewModel.favorites
            .filter { videoIds.contains($0.videoId) }
            .sorted { $0.timeSeconds < $1.timeSeconds }
            .compactMap { snapshot in
                videosInFolder.first(where: { $0.id == snapshot.videoId }).map { (snapshot, $0) }
            }
    }

    private func video(for id: UUID) -> VideoFile? {
        libraryViewModel.videos.first { $0.id == id }
    }
}

