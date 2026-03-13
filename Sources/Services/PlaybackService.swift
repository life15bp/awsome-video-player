import AVFoundation
import Combine

final class PlaybackService: ObservableObject {
    @Published private(set) var player: AVPlayer?
    @Published private(set) var currentFile: VideoFile?
    @Published private(set) var currentTime: CMTime = .zero
    @Published private(set) var duration: CMTime = .zero

    private var timeObserverToken: Any?

    deinit {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
        }
    }

    func load(file: VideoFile) {
        currentFile = file

        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }

        let player = AVPlayer(url: file.url)
        self.player = player
        duration = .zero

        if let item = player.currentItem {
            Task { @MainActor in
                do {
                    let d = try await item.asset.load(.duration)
                    self.duration = d
                } catch {
                    self.duration = .zero
                }
            }
        }

        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = time
        }
    }

    func play() {
        player?.play()
    }

    func pause() {
        player?.pause()
    }

    func seek(to seconds: Double) {
        let target = CMTime(seconds: seconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
    }
}


