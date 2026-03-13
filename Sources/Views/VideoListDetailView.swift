import SwiftUI
import AppKit

/// メインウィンドウ右側: 選択フォルダ内の動画を1行ずつ表示。各行 = 通常サムネイル | お気に入りサムネイル1 | 2 | 3 ...
/// お気に入りがなくても動画は一覧に表示する。
struct VideoListDetailView: View {
    @EnvironmentObject private var libraryViewModel: LibraryViewModel
    @EnvironmentObject private var playerViewModel: PlayerViewModel
    @Environment(\.openWindow) private var openWindow

    private let mainThumbSize = CGSize(width: 200, height: 112)
    private let favThumbSize = CGSize(width: 160, height: 90)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if libraryViewModel.selectedFolder == nil {
                emptyMessage("左でフォルダを選択してください")
            } else if libraryViewModel.videosInSelectedFolder.isEmpty {
                emptyMessage("このフォルダに動画はありません")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(libraryViewModel.videosInSelectedFolder) { video in
                            videoRow(video: video)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func videoRow(video: VideoFile) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // 通常のサムネイル（左端固定）
            VStack(alignment: .leading, spacing: 4) {
                mainThumbnail(video: video)
                    .onTapGesture {
                        libraryViewModel.selectedVideo = video
                        playerViewModel.load(file: video)
                        openWindow(id: "playerWindow")
                    }
                Text(video.displayName)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundColor(.secondary)
            }
            .frame(width: mainThumbSize.width, alignment: .leading)

            // 縦線で区切り
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 1)
                .padding(.horizontal, 8)

            // お気に入り箇所サムネイル1 | 2 | 3 ...
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(favoritesForVideo(video)) { snapshot in
                        FavoriteSnapshotThumbnailView(
                            video: video,
                            snapshot: snapshot,
                            size: favThumbSize
                        )
                        .onTapGesture {
                            playerViewModel.playSnapshot(snapshot, video: video)
                            openWindow(id: "playerWindow")
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.primary.opacity(0.03))
    }

    private func mainThumbnail(video: VideoFile) -> some View {
        Group {
            if let image = libraryViewModel.thumbnail(for: video, targetSize: mainThumbSize) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                    ProgressView()
                }
            }
        }
        .frame(width: mainThumbSize.width, height: mainThumbSize.height)
        .clipped()
    }

    private func favoritesForVideo(_ video: VideoFile) -> [FavoriteSnapshot] {
        playerViewModel.favorites
            .filter { $0.videoId == video.id }
            .sorted { $0.timeSeconds < $1.timeSeconds }
    }

    private func emptyMessage(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
