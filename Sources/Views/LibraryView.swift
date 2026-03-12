import SwiftUI
import AppKit

struct LibraryView: View {
    @EnvironmentObject private var libraryViewModel: LibraryViewModel

    let videos: [VideoFile]
    let onVideoDoubleTap: (VideoFile) -> Void
    let onAddFolder: (URL) -> Void

    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 180), spacing: 12, alignment: .top)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("Add Folder…") {
                    openFolderPicker()
                }
                Spacer()
            }
            .padding(.bottom, 4)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(videos) { video in
                        VStack(alignment: .leading, spacing: 6) {
                            thumbnailView(for: video)
                                .aspectRatio(16 / 9, contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .clipped()

                            Text(video.displayName)
                                .font(.caption)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onVideoDoubleTap(video)
                        }
                    }
                }
            }
        }
        .padding()
    }

    @ViewBuilder
    private func thumbnailView(for video: VideoFile) -> some View {
        if let image = libraryViewModel.thumbnail(for: video) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .background(Color.black.opacity(0.7))
        } else {
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                ProgressView()
            }
        }
    }

    private func openFolderPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            onAddFolder(url)
        }
    }
}


