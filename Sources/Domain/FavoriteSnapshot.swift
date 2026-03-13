import Foundation

struct FavoriteSnapshot: Identifiable, Codable, Hashable {
    let id: UUID
    let videoId: UUID
    let timeSeconds: Double
    var tags: [String]
    /// このお気に入りを動画のメインサムネイルとして使うか（お気に入り中のお気に入り）
    var useAsVideoThumbnail: Bool

    init(
        id: UUID = UUID(),
        videoId: UUID,
        timeSeconds: Double,
        tags: [String] = [],
        useAsVideoThumbnail: Bool = false
    ) {
        self.id = id
        self.videoId = videoId
        self.timeSeconds = timeSeconds
        self.tags = tags
        self.useAsVideoThumbnail = useAsVideoThumbnail
    }

    private enum CodingKeys: String, CodingKey {
        case id, videoId, timeSeconds, tags, useAsVideoThumbnail
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        videoId = try c.decode(UUID.self, forKey: .videoId)
        timeSeconds = try c.decode(Double.self, forKey: .timeSeconds)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        useAsVideoThumbnail = try c.decodeIfPresent(Bool.self, forKey: .useAsVideoThumbnail) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(videoId, forKey: .videoId)
        try c.encode(timeSeconds, forKey: .timeSeconds)
        try c.encode(tags, forKey: .tags)
        try c.encode(useAsVideoThumbnail, forKey: .useAsVideoThumbnail)
    }
}

