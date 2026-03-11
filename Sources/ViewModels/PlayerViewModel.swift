import Foundation
import AVFoundation

final class PlayerViewModel: ObservableObject {
    @Published private(set) var currentFile: VideoFile?
    @Published private(set) var player: AVPlayer?

    private let playbackService: PlaybackService

    init(playbackService: PlaybackService) {
        self.playbackService = playbackService
    }

    func load(file: VideoFile) {
        currentFile = file
        playbackService.load(file: file)
        player = playbackService.player
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
}


