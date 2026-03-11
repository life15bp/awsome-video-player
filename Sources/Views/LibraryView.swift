import SwiftUI
import AppKit

struct LibraryView: View {
    let videos: [VideoFile]
    let onVideoDoubleTap: (VideoFile) -> Void
    let onAddFolder: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button("Add Folder…") {
                    openFolderPicker()
                }
                Spacer()
            }
            .padding(.bottom, 4)

            List(videos) { video in
                Text(video.displayName)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        onVideoDoubleTap(video)
                    }
            }
        }
        .padding()
    }

    private func openFolderPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            onAddFolder(url)
        }
    }
}

