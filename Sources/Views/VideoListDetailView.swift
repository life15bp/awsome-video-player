import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// 動画行ドラッグ時のプレフィックス（LibraryView の onDrop と一致させる）
private let videoIdDragPrefix = "avp-video-id:"

/// メインウィンドウ右側: 選択フォルダ内の動画を1行ずつ表示。各行 = 通常サムネイル | お気に入りサムネイル1 | 2 | 3 ...
/// お気に入りがなくても動画は一覧に表示する。
struct VideoListDetailView: View {
    @EnvironmentObject private var libraryViewModel: LibraryViewModel
    @EnvironmentObject private var playerViewModel: PlayerViewModel
    @Environment(\.openWindow) private var openWindow

    private let mainThumbSize = CGSize(width: 200, height: 112)
    private let favThumbSize = CGSize(width: 160, height: 90)

    /// 左ペインのタブ・選択に応じた表示用動画一覧
    private var displayedVideos: [VideoFile] {
        switch libraryViewModel.leftPaneTab {
        case .folder:
            return libraryViewModel.videosInSelectedFolder
        case .tag:
            if let tag = libraryViewModel.selectedTagForFilter {
                return libraryViewModel.videos.filter { playerViewModel.videoIdsWithTag(tag).contains($0.id) }
            } else {
                return libraryViewModel.videos.filter { playerViewModel.videoIdsWithAtLeastOneFavorite.contains($0.id) }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if libraryViewModel.leftPaneTab == .folder {
                if libraryViewModel.selectedFolder == nil {
                    emptyMessage("左でフォルダを選択してください")
                } else if displayedVideos.isEmpty {
                    emptyMessage("このフォルダに動画はありません")
                } else {
                    listContent
                }
            } else {
                if displayedVideos.isEmpty {
                    emptyMessage("該当する動画はありません")
                } else {
                    listContent
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: libraryViewModel.selectedFolder) { _ in
            DispatchQueue.main.async {
                playerViewModel.reloadFavoritesFromDisk()
            }
        }
    }

    private var listContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(displayedVideos) { video in
                    videoRow(video: video)
                }
            }
        }
    }

    private func videoRow(video: VideoFile) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 0) {
                // 通常のサムネイル（左端固定）— ここをドラッグして左ペインのフォルダへ移動できる
                VStack(alignment: .leading, spacing: 4) {
                    mainThumbnail(video: video)
                        .onTapGesture {
                            libraryViewModel.selectedVideo = video
                            playerViewModel.load(file: video)
                            openWindow(id: "playerWindow")
                        }
                        .onDrag {
                            NSItemProvider(object: (videoIdDragPrefix + video.id.uuidString) as NSString)
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
                                size: favThumbSize,
                                isPrimaryThumbnail: playerViewModel.primaryThumbnailSnapshot(for: video)?.id == snapshot.id,
                                onDelete: { playerViewModel.removeFavorite(snapshot) },
                                onSetAsMainThumbnail: { playerViewModel.setAsMainThumbnail(snapshot) },
                                onAddTag: { name in playerViewModel.addTag(name, to: snapshot) },
                                onRemoveTag: { name in playerViewModel.removeTag(name, from: snapshot) }
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

            videoTagsSection(video: video)
            let favoriteTags = playerViewModel.tagsForVideo(video)
            if !favoriteTags.isEmpty {
                HStack(spacing: 4) {
                    Text("お気に入りタグ:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ForEach(favoriteTags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Color.secondary.opacity(0.2))
                            )
                    }
                }
                .padding(.leading, 8)
                .padding(.bottom, 4)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.primary.opacity(0.03))
        .contextMenu {
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([video.url])
            }
            Button("動画にタグを追加…") {
                showAddVideoTagAlert(video: video)
            }
            Button("削除", role: .destructive) {
                confirmAndDeleteVideo(video)
            }
        }
    }

    private func videoTagsSection(video: VideoFile) -> some View {
        let tags = playerViewModel.videoTags(for: video)
        return HStack(spacing: 4) {
            Text("動画タグ:")
                .font(.caption)
                .foregroundColor(.secondary)
            ForEach(tags, id: \.self) { tag in
                HStack(spacing: 2) {
                    Text(tag)
                        .font(.caption2)
                    Button {
                        playerViewModel.removeVideoTag(tag, from: video)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.secondary.opacity(0.2)))
            }
            Button {
                showAddVideoTagAlert(video: video)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 8)
        .padding(.bottom, 4)
    }

    private func showAddVideoTagAlert(video: VideoFile) {
        let alert = NSAlert()
        alert.messageText = "動画にタグを追加"
        alert.informativeText = "タグ名を入力してください。"
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 22))
        textField.placeholderString = "タグ名"
        alert.accessoryView = textField
        alert.addButton(withTitle: "追加")
        alert.addButton(withTitle: "キャンセル")
        alert.window.initialFirstResponder = textField
        if alert.runModal() == .alertFirstButtonReturn {
            let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                playerViewModel.addVideoTag(name, to: video)
            }
        }
    }

    private func confirmAndDeleteVideo(_ video: VideoFile) {
        let alert = NSAlert()
        alert.messageText = "動画を削除しますか？"
        alert.informativeText = "「\(video.displayName)」をゴミ箱に移動します。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "削除")
        alert.addButton(withTitle: "キャンセル")
        if alert.runModal() == .alertFirstButtonReturn {
            playerViewModel.removeFavoritesForVideo(videoId: video.id)
            playerViewModel.removeVideoTagsForVideo(videoId: video.id)
            if libraryViewModel.deleteVideo(video) {
                // 削除完了
            } else {
                let err = NSAlert()
                err.messageText = "ゴミ箱に移動できませんでした"
                err.informativeText = "ファイルの権限を確認してください。"
                err.alertStyle = .warning
                err.runModal()
            }
        }
    }

    private func mainThumbnail(video: VideoFile) -> some View {
        Group {
            if let image = libraryViewModel.thumbnail(for: video, at: playerViewModel.primaryThumbnailTime(for: video), targetSize: mainThumbSize) {
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
