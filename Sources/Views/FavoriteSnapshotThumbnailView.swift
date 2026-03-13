import SwiftUI
import AppKit

struct FavoriteSnapshotThumbnailView: View {
    let video: VideoFile
    let snapshot: FavoriteSnapshot
    let size: CGSize
    var onDelete: (() -> Void)?

    @State private var image: NSImage?
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 2) {
            ZStack(alignment: .topTrailing) {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.4))
                    ProgressView()
                }

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
            .frame(width: size.width, height: size.height)
            .clipped()
            .onHover { isHovering = $0 }

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
