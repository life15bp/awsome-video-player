import Foundation
import AVFoundation

final class PlayerViewModel: ObservableObject {
    @Published private(set) var currentFile: VideoFile?
    @Published private(set) var player: AVPlayer?
    @Published private(set) var viewport = ViewportState()
    @Published private(set) var favorites: [FavoriteSnapshot] = []

    private let playbackService: PlaybackService
    private let favoriteService: FavoriteService

    init(playbackService: PlaybackService, favoriteService: FavoriteService) {
        self.playbackService = playbackService
        self.favoriteService = favoriteService
        self.favorites = favoriteService.loadFavorites()
    }

    func load(file: VideoFile) {
        currentFile = file
        playbackService.load(file: file)
        player = playbackService.player
        viewport = ViewportState()
    }

    var favoritesForCurrentFile: [FavoriteSnapshot] {
        guard let currentFile else { return [] }
        return favorites
            .filter { $0.videoId == currentFile.id }
            .sorted { $0.timeSeconds < $1.timeSeconds }
    }

    var currentSeconds: Double {
        guard CMTIME_IS_NUMERIC(playbackService.currentTime) else { return 0 }
        return CMTimeGetSeconds(playbackService.currentTime)
    }

    var durationSeconds: Double {
        guard CMTIME_IS_NUMERIC(playbackService.duration) else { return 0 }
        return CMTimeGetSeconds(playbackService.duration)
    }

    var progress: Double {
        let duration = durationSeconds
        guard duration > 0 else { return 0 }
        return currentSeconds / duration
    }

    func seek(to progress: Double) {
        let duration = durationSeconds
        guard duration > 0 else { return }
        let seconds = duration * min(max(progress, 0), 1)
        playbackService.seek(to: seconds)
    }

    func play() {
        playbackService.play()
    }

    func pause() {
        playbackService.pause()
    }

    func formattedTime(_ seconds: Double) -> String {
        guard seconds.isFinite && !seconds.isNaN else { return "00:00" }
        let total = Int(seconds.rounded())
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Viewport control

    func zoom(byScrollDelta deltaY: CGFloat) {
        // スクロール量をそのまま使うと変化が分かりにくいので、少し大きめに反映
        let sensitivity: CGFloat = -0.1
        let deltaScale = deltaY * sensitivity
        viewport.applyScale(delta: deltaScale)
    }

    func pan(by translation: CGSize) {
        viewport.applyPan(translation: translation)
    }

    func scrub(byHorizontalDelta deltaX: CGFloat) {
        let duration = durationSeconds
        guard duration > 0 else { return }

        let sensitivity: Double = 0.002
        let deltaSeconds = Double(deltaX) * sensitivity * duration
        let newSeconds = min(max(currentSeconds + deltaSeconds, 0), duration)
        playbackService.seek(to: newSeconds)
    }

    // MARK: - Favorites

    func addFavoriteAtCurrentTime() {
        guard let currentFile else { return }
        let seconds = currentSeconds
        let snapshot = FavoriteSnapshot(videoId: currentFile.id, timeSeconds: seconds)
        favorites.append(snapshot)
        favorites.sort { $0.timeSeconds < $1.timeSeconds }
        favoriteService.saveFavorites(favorites)
    }

    func seek(to snapshot: FavoriteSnapshot) {
        playbackService.seek(to: snapshot.timeSeconds)
    }
}
