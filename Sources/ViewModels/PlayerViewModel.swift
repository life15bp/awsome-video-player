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

    func play() {
        playbackService.play()
    }

    func pause() {
        playbackService.pause()
    }
}

