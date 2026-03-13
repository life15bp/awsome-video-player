import SwiftUI

/// メインウィンドウの右側: 選択中フォルダの「お気に入りサムネイル」一覧。タップでプレーヤーウィンドウを開きその時間から再生。
struct FolderFavoritesDetailView: View {
    @EnvironmentObject private var libraryViewModel: LibraryViewModel
    @EnvironmentObject private var playerViewModel: PlayerViewModel
    @Environment(\.openWindow) private var openWindow

    private let thumbnailSize = CGSize(width: 240, height: 135)
    private let columns = [GridItem(.adaptive(minimum: 200), spacing: 12, alignment: .top)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("お気に入り")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            if libraryViewModel.selectedFolder == nil {
                emptyMessage("左でフォルダを選択してください")
            } else if folderFavorites.isEmpty {
                emptyMessage("このフォルダにお気に入りはありません")
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(folderFavorites, id: \.snapshot.id) { item in
                            FavoriteSnapshotThumbnailView(
                                video: item.video,
                                snapshot: item.snapshot,
                                size: thumbnailSize
                            )
                            .onTapGesture {
                                playerViewModel.playSnapshot(item.snapshot, video: item.video)
                                openWindow(id: "playerWindow")
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var folderFavorites: [(snapshot: FavoriteSnapshot, video: VideoFile)] {
        let videosInFolder = libraryViewModel.videosInSelectedFolder
        let videoIds = Set(videosInFolder.map(\.id))
        return playerViewModel.favorites
            .filter { videoIds.contains($0.videoId) }
            .sorted { $0.timeSeconds < $1.timeSeconds }
            .compactMap { snapshot in
                videosInFolder.first(where: { $0.id == snapshot.videoId }).map { (snapshot, $0) }
            }
    }

    private func emptyMessage(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
