import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// 動画 ID をドラッグ時にプレーンテキストで渡すためのプレフィックス（他アプリのテキスト D&D と区別）
private let videoIdDragPrefix = "avp-video-id:"
/// フォルダ並べ替え用ドラッグのプレフィックス（ルートフォルダの index）
private let folderOrderDragPrefix = "avp-folder-order:"
/// フォルダ移動・並べ替え用（path とオプションでルート index）
private let folderDragPrefix = "avp-folder:"
/// タグ並べ替え用ドラッグのプレフィックス（タグ名を渡す）
private let tagOrderDragPrefix = "avp-tag:"

/// フォルダ行をドラッグ可能に（フォルダの移動とルートの並べ替えの両方に対応）
private struct FolderDragModifier: ViewModifier {
    let node: FolderNode
    let rootIndex: Int?

    func body(content: Content) -> some View {
        content.onDrag {
            let path = node.url.path
            let payload = rootIndex.map { folderDragPrefix + path + "|" + String($0) } ?? (folderDragPrefix + path)
            return NSItemProvider(object: payload as NSString)
        }
    }
}

struct LibraryView: View {
    @EnvironmentObject private var libraryViewModel: LibraryViewModel
    @EnvironmentObject private var playerViewModel: PlayerViewModel

    let onAddFolder: (URL) -> Void

    /// Finder 風の開閉状態（展開しているフォルダの id 一覧）
    @State private var expandedFolderIds: Set<String> = []
    @State private var dropTargetFolderId: String?
    /// タグタブで D&D のドロップ先としてハイライトする行のインデックス（orderedTagsForFilter 上）
    @State private var dropTargetTagIndex: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            leftPaneTabPicker
            if libraryViewModel.leftPaneTab == .folder {
                folderTreeView
            } else {
                tagFilterView
            }
        }
        .padding()
    }

    /// フォルダ / タグ のタブ切り替え
    private var leftPaneTabPicker: some View {
        Picker("", selection: $libraryViewModel.leftPaneTab) {
            ForEach(LeftPaneTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.bottom, 4)
    }

    /// タグタブ: 「お気に入り」＋タグ一覧でフィルタ選択（タグは D&D で並べ替え可能）
    private var tagFilterView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("フィルタ")
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    tagFilterRow(label: "お気に入り", isSelected: libraryViewModel.selectedTagForFilter == nil) {
                        libraryViewModel.selectedTagForFilter = nil
                    }
                    ForEach(Array(playerViewModel.orderedTagsForFilter.enumerated()), id: \.element) { index, tag in
                        tagFilterRow(
                            label: tag,
                            isSelected: libraryViewModel.selectedTagForFilter == tag,
                            isDropTarget: dropTargetTagIndex == index
                        ) {
                            libraryViewModel.selectedTagForFilter = tag
                        }
                        .onDrag {
                            NSItemProvider(object: (tagOrderDragPrefix + tag) as NSString)
                        }
                        .onDrop(of: [.utf8PlainText], isTargeted: Binding(
                            get: { dropTargetTagIndex == index },
                            set: { dropTargetTagIndex = $0 ? index : nil }
                        )) { providers in
                            acceptTagDrop(providers: providers, destinationIndex: index)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 200)
    }

    private func acceptTagDrop(providers: [NSItemProvider], destinationIndex: Int) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: String.self) { obj, _ in
            guard let s = obj as? String, s.hasPrefix(tagOrderDragPrefix) else { return }
            let tag = String(s.dropFirst(tagOrderDragPrefix.count))
            DispatchQueue.main.async {
                let order = playerViewModel.orderedTagsForFilter
                guard let sourceIndex = order.firstIndex(of: tag), sourceIndex != destinationIndex else {
                    dropTargetTagIndex = nil
                    return
                }
                playerViewModel.reorderTags(from: sourceIndex, to: destinationIndex)
                dropTargetTagIndex = nil
            }
        }
        return true
    }

    private func tagFilterRow(label: String, isSelected: Bool, isDropTarget: Bool = false, action: @escaping () -> Void) -> some View {
        Text(label)
            .lineLimit(1)
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : (isDropTarget ? Color.accentColor.opacity(0.15) : Color.clear))
            )
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
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
                        ForEach(Array(libraryViewModel.folderTree.enumerated()), id: \.element.id) { index, node in
                            folderRow(node: node, indent: 0, rootIndex: index)
                        }
                    }
                }
                .onAppear {
                    if expandedFolderIds.isEmpty, !libraryViewModel.folderTree.isEmpty {
                        expandedFolderIds = Set(libraryViewModel.folderTree.map(\.id))
                    }
                }
            }
        }
        .frame(minWidth: 200)
    }

    private func folderRow(node: FolderNode, indent: CGFloat, rootIndex: Int? = nil) -> AnyView {
        let isSelected = node.url == libraryViewModel.selectedFolder
        let hasChildren = !node.children.isEmpty
        let isExpanded = expandedFolderIds.contains(node.id)
        let isDropTarget = dropTargetFolderId == node.id
        let isRoot = rootIndex != nil

        let content = VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if hasChildren {
                    Button {
                        if isExpanded {
                            expandedFolderIds.remove(node.id)
                        } else {
                            expandedFolderIds.insert(node.id)
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 14, alignment: .center)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer()
                        .frame(width: 14)
                }

                Text(node.name)
                    .lineLimit(1)
                    .font(.callout)
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : (isDropTarget ? Color.accentColor.opacity(0.15) : Color.clear))
            )
            .contentShape(Rectangle())
            .padding(.leading, indent)
            .onTapGesture {
                libraryViewModel.selectedFolder = node.url
            }
            .onDrop(of: [.utf8PlainText], isTargeted: Binding(
                get: { isDropTarget },
                set: { dropTargetFolderId = $0 ? node.id : nil }
            )) { providers in
                acceptDrop(providers: providers, folderURL: node.url, folderRootIndex: rootIndex)
            }
            .modifier(FolderDragModifier(node: node, rootIndex: rootIndex))
            .contextMenu {
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([node.url])
                }
                Button("更新") {
                    // フォルダ配下の動画一覧とツリーを再スキャン
                    libraryViewModel.refreshAllVideos()
                }
                Button("フォルダ名の変更…") {
                    showRenameFolderAlert(url: node.url, currentName: node.name)
                }
                Button("子フォルダを作成…") {
                    showNewFolderAlert(parentURL: node.url)
                }
                Divider()
                if libraryViewModel.isRootFolder(node.url) {
                    Button("ライブラリから削除", role: .destructive) {
                        libraryViewModel.removeFolder(node.url)
                    }
                } else {
                    Button("削除", role: .destructive) {
                        confirmAndDeleteFolder(node.url, name: node.name)
                    }
                }
            }

            if hasChildren, isExpanded {
                ForEach(node.children) { child in
                    folderRow(node: child, indent: indent + 12, rootIndex: nil)
                }
            }
        }

        return AnyView(content)
    }

    private func acceptDrop(providers: [NSItemProvider], folderURL: URL, folderRootIndex: Int?) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: String.self) { obj, _ in
            guard let s = obj as? String else { return }
            DispatchQueue.main.async {
                if s.hasPrefix(folderDragPrefix) {
                    let rest = String(s.dropFirst(folderDragPrefix.count))
                    let sourcePath: String
                    let sourceRootIndex: Int?
                    if let lastBar = rest.lastIndex(of: "|") {
                        sourcePath = String(rest[..<lastBar])
                        sourceRootIndex = Int(rest[rest.index(after: lastBar)...])
                    } else {
                        sourcePath = rest
                        sourceRootIndex = nil
                    }
                    if let srcIdx = sourceRootIndex, let destIdx = folderRootIndex {
                        libraryViewModel.reorderFolders(from: srcIdx, to: destIdx)
                    } else {
                        let sourceURL = URL(fileURLWithPath: sourcePath)
                        _ = libraryViewModel.moveFolder(from: sourceURL, to: folderURL)
                    }
                } else if s.hasPrefix(folderOrderDragPrefix), let destIndex = folderRootIndex {
                    let rest = String(s.dropFirst(folderOrderDragPrefix.count))
                    guard let sourceIndex = Int(rest) else { return }
                    libraryViewModel.reorderFolders(from: sourceIndex, to: destIndex)
                } else if s.hasPrefix(videoIdDragPrefix),
                          let id = UUID(uuidString: String(s.dropFirst(videoIdDragPrefix.count))) {
                    guard let video = libraryViewModel.video(byId: id) else { return }
                    _ = libraryViewModel.moveVideo(video, to: folderURL)
                }
                dropTargetFolderId = nil
            }
        }
        return true
    }

    private func openFolderPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            // 次回起動後も同じフォルダにアクセスできるよう、スコープを取得してから追加する
            _ = url.startAccessingSecurityScopedResource()
            onAddFolder(url)
        }
    }

    /// 子フォルダ作成を AppKit の NSAlert で表示（macOS で確実にボタンが反応する）
    private func showNewFolderAlert(parentURL: URL) {
        let alert = NSAlert()
        alert.messageText = "子フォルダを作成"
        alert.informativeText = "フォルダ名を入力してください。"
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 22))
        textField.placeholderString = "フォルダ名"
        alert.accessoryView = textField
        alert.addButton(withTitle: "作成")
        alert.addButton(withTitle: "キャンセル")
        alert.window.initialFirstResponder = textField

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let name = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                let result = libraryViewModel.createSubfolder(name: name, under: parentURL)
                if !result.success {
                    let errAlert = NSAlert()
                    errAlert.messageText = "子フォルダを作成できませんでした"
                    errAlert.informativeText = result.errorMessage ?? "書き込み権限を確認してください。"
                    errAlert.alertStyle = .warning
                    errAlert.runModal()
                }
            }
        }
    }

    /// 子フォルダをゴミ箱へ移動する確認ダイアログ
    private func confirmAndDeleteFolder(_ url: URL, name: String) {
        let alert = NSAlert()
        alert.messageText = "フォルダを削除しますか？"
        alert.informativeText = "「\(name)」をゴミ箱に移動します。フォルダ内のファイルも一緒に移動します。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "削除")
        alert.addButton(withTitle: "キャンセル")
        if alert.runModal() == .alertFirstButtonReturn {
            if !libraryViewModel.deleteFolder(at: url) {
                let err = NSAlert()
                err.messageText = "ゴミ箱に移動できませんでした"
                err.informativeText = "フォルダの権限を確認してください。"
                err.alertStyle = .warning
                err.runModal()
            }
        }
    }

    /// フォルダ名変更ダイアログ
    private func showRenameFolderAlert(url: URL, currentName: String) {
        let alert = NSAlert()
        alert.messageText = "フォルダ名の変更"
        alert.informativeText = "新しいフォルダ名を入力してください。"
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 22))
        textField.stringValue = currentName
        textField.placeholderString = "フォルダ名"
        alert.accessoryView = textField
        alert.addButton(withTitle: "変更")
        alert.addButton(withTitle: "キャンセル")
        alert.window.initialFirstResponder = textField
        if alert.runModal() == .alertFirstButtonReturn {
            let newName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newName.isEmpty {
                let result = libraryViewModel.renameFolder(at: url, to: newName)
                if !result.success {
                    let err = NSAlert()
                    err.messageText = "フォルダ名を変更できませんでした"
                    err.informativeText = result.errorMessage ?? "権限を確認してください。"
                    err.alertStyle = .warning
                    err.runModal()
                }
            }
        }
    }
}


