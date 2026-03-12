import Foundation

struct FavoriteSnapshot: Identifiable, Codable, Hashable {
    let id: UUID
    let videoId: UUID
    let timeSeconds: Double

    init(id: UUID = UUID(), videoId: UUID, timeSeconds: Double) {
        self.id = id
        self.videoId = videoId
        self.timeSeconds = timeSeconds
    }
}

