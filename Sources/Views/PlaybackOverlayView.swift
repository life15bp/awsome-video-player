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
                sameFolderList
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

    private var sameFolderList: some View {
        Group {
            if let current = playerViewModel.currentFile {
                let items = libraryViewModel.videosInSameFolder(as: current)
                VStack(alignment: .leading, spacing: 4) {
                    Text("同フォルダ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.top, 6)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(items) { video in
                                HStack {
                                    Text(video.displayName)
                                        .lineLimit(1)
                                        .font(.caption)
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(video.id == current.id ? Color.white.opacity(0.2) : Color.clear)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    libraryViewModel.selectedVideo = video
                                    playerViewModel.load(file: video)
                                    playerViewModel.play()
                                }
                            }
                        }
                        .padding(.bottom, 6)
                    }
                }
                .frame(width: 220, height: 260)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.6))
                )
                .padding([.trailing, .bottom], 12)
            }
        }
    }

    private func video(for id: UUID) -> VideoFile? {
        libraryViewModel.videos.first { $0.id == id }
    }
}

private struct FavoriteSnapshotThumbnailView: View {
    let video: VideoFile
    let snapshot: FavoriteSnapshot
    let size: CGSize

    @State private var image: NSImage?

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.4))
                    ProgressView()
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()

            Text(timeLabel)
                .font(.caption2)
                .foregroundColor(.white)
        }
        .onAppear {
            loadIfNeeded()
        }
    }

    private var timeLabel: String {
        let total = Int(snapshot.timeSeconds.rounded())
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func loadIfNeeded() {
        guard image == nil else { return }
        // Retina を意識して 2 倍解像度で生成
        let pixelSize = CGSize(width: size.width * 2, height: size.height * 2)
        ThumbnailService.shared.thumbnail(
            for: video.url,
            at: snapshot.timeSeconds,
            targetSize: pixelSize
        ) { loaded in
            self.image = loaded
        }
    }
}

