import SwiftUI
import AppKit

struct LibraryView: View {
    @EnvironmentObject private var libraryViewModel: LibraryViewModel

    let onAddFolder: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            folderTreeView
        }
        .padding()
    }

    private var header: some View {
        HStack {
            Button("Add Folder…") {
                openFolderPicker()
            }
            Spacer()
        }
        .padding(.bottom, 4)
    }

    private var folderTreeView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Folders")
                .font(.caption)
                .foregroundColor(.secondary)

            if libraryViewModel.folderTree.isEmpty {
                Text("フォルダを追加してください")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(8)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(libraryViewModel.folderTree) { node in
                            folderRow(node: node, indent: 0)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 200)
    }

    private func folderRow(node: FolderNode, indent: CGFloat) -> AnyView {
        let isSelected = node.url == libraryViewModel.selectedFolder

        let content = VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(node.name)
                    .lineLimit(1)
                    .font(.callout)
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            )
            .contentShape(Rectangle())
            .padding(.leading, indent)
            .onTapGesture {
                libraryViewModel.selectedFolder = node.url
            }

            ForEach(node.children) { child in
                folderRow(node: child, indent: indent + 12)
            }
        }

        return AnyView(content)
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


