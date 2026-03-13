import Foundation

struct FavoriteSnapshot: Identifiable, Codable, Hashable {
    let id: UUID
    let videoId: UUID
    let timeSeconds: Double
    var tags: [String]

    init(
        id: UUID = UUID(),
        videoId: UUID,
        timeSeconds: Double,
        tags: [String] = []
    ) {
        self.id = id
        self.videoId = videoId
        self.timeSeconds = timeSeconds
        self.tags = tags
    }
}

