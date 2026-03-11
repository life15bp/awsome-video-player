import Foundation

struct VideoFile: Identifiable, Hashable, Codable {
    let id: UUID
    let url: URL
    let displayName: String
    let durationSeconds: Double?

    init(id: UUID = UUID(), url: URL, displayName: String? = nil, durationSeconds: Double? = nil) {
        self.id = id
        self.url = url
        self.displayName = displayName ?? url.lastPathComponent
        self.durationSeconds = durationSeconds
    }
}

