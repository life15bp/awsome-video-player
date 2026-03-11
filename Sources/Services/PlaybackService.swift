import AVFoundation

final class PlaybackService: ObservableObject {
    @Published private(set) var player: AVPlayer?
    @Published private(set) var currentFile: VideoFile?

    func load(file: VideoFile) {
        currentFile = file
        player = AVPlayer(url: file.url)
    }

    func play() {
        player?.play()
    }

    func pause() {
        player?.pause()
    }
}

