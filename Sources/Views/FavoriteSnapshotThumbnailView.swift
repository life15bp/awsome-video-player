import SwiftUI
import AppKit

struct FavoriteSnapshotThumbnailView: View {
    let video: VideoFile
    let snapshot: FavoriteSnapshot
    let size: CGSize
    /// このお気に入りが動画のメインサムネイルに選ばれているか（お気に入り中のお気に入り）
    var isPrimaryThumbnail: Bool = false
    var onDelete: (() -> Void)?
    var onSetAsMainThumbnail: (() -> Void)?
    var onAddTag: ((String) -> Void)?
    var onRemoveTag: ((String) -> Void)?

    @State private var image: NSImage?
    @State private var isHovering = false
    @State private var isEditingTag = false
    @State private var newTagText = ""

    var body: some View {
        VStack(spacing: 2) {
            ZStack(alignment: .topLeading) {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.4))
                    ProgressView()
                }

                HStack {
                    if onSetAsMainThumbnail != nil {
                        Button(action: { onSetAsMainThumbnail?() }) {
                            Image(systemName: isPrimaryThumbnail ? "star.fill" : "star")
                                .font(.title3)
                                .foregroundStyle(isPrimaryThumbnail ? Color.yellow : .white.opacity(0.8))
                                .symbolRenderingMode(.hierarchical)
                        }
                        .buttonStyle(.plain)
                        .padding(4)
                    }
                    Spacer()
                    if onDelete != nil, isHovering {
                        Button(action: { onDelete?() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .symbolRenderingMode(.hierarchical)
                        }
                        .buttonStyle(.plain)
                        .padding(4)
                    }
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .onHover { isHovering = $0 }

            Text(timeLabel)
                .font(.caption2)
                .foregroundColor(.white)

            // タグ一覧
            HStack(spacing: 4) {
                ForEach(snapshot.tags, id: \.self) { tag in
                    HStack(spacing: 2) {
                        Text(tag)
                        if let onRemoveTag {
                            Button {
                                onRemoveTag(tag)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        Capsule().fill(Color.black.opacity(0.5))
                    )
                }

                if onAddTag != nil {
                    Button {
                        isEditingTag = true
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        // macOS 13 だと popover 内の TextField がフォーカスを取りづらいことがあるので、
        // 一旦 sheet で安定して文字入力できるようにする
        .sheet(isPresented: $isEditingTag) {
            VStack(alignment: .leading, spacing: 8) {
                Text("タグを追加")
                    .font(.headline)
                TextField("タグ名", text: $newTagText, onCommit: commitNewTag)
                HStack {
                    Spacer()
                    Button("追加") { commitNewTag() }
                }
            }
            .padding()
            .frame(width: 260)
        }
        .onAppear {
            loadIfNeeded()
        }
    }

    private func commitNewTag() {
        let text = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let onAddTag else { return }
        onAddTag(text)
        newTagText = ""
        isEditingTag = false
    }

    private var timeLabel: String {
        let total = Int(snapshot.timeSeconds.rounded())
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func loadIfNeeded() {
        guard image == nil else { return }
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
