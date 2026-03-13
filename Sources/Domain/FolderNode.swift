import Foundation

/// フォルダツリー表示用のノード（追加したルートフォルダとそのサブディレクトリ）
struct FolderNode: Identifiable {
    let id: String
    let url: URL
    let name: String
    var children: [FolderNode]

    init(url: URL, name: String? = nil, children: [FolderNode] = []) {
        self.id = url.path
        self.url = url
        self.name = name ?? url.lastPathComponent
        self.children = children
    }
}
