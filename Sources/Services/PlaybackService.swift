import AVFoundation
import Combine

final class PlaybackService: ObservableObject {
    @Published private(set) var player: AVPlayer?
    @Published private(set) var currentFile: VideoFile?
    @Published private(set) var currentTime: CMTime = .zero
    @Published private(set) var duration: CMTime = .zero
    /// 1コマの長さ（秒）。アセットの動画トラックから取得、取得できない場合は 1/30 秒
    @Published private(set) var frameDurationInSeconds: Double = 1.0 / 30.0
    /// 再生失敗時（AVPlayerItem.status == .failed）のメッセージ。nil ならエラーなし
    @Published private(set) var playbackError: String?

    private var timeObserverToken: Any?
    private var itemStatusObservation: NSKeyValueObservation?

    deinit {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
        }
    }

    func load(file: VideoFile) {
        currentFile = file
        playbackError = nil
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil

        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }

        if file.url.pathExtension.lowercased() == "mkv" {
            player = nil
            duration = .zero
            currentTime = .zero
            frameDurationInSeconds = 1.0 / 30.0
            return
        }

        let player = AVPlayer(url: file.url)
        self.player = player
        duration = .zero

        if let item = player.currentItem {
            itemStatusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if item.status == .failed {
                        self.playbackError = item.error?.localizedDescription ?? "このファイルは再生できません"
                    }
                }
            }
        }

        if let item = player.currentItem {
            frameDurationInSeconds = 1.0 / 30.0
            Task { @MainActor in
                do {
                    let d = try await item.asset.load(.duration)
                    self.duration = d
                } catch {
                    self.duration = .zero
                }
                if let tracks = try? await item.asset.load(.tracks),
                   let video = tracks.first(where: { $0.mediaType == .video }),
                   let rate = try? await video.load(.nominalFrameRate), rate > 0 {
                    self.frameDurationInSeconds = 1.0 / Double(rate)
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

    var currentRate: Float {
        player?.rate ?? 1.0
    }

    func setRate(_ rate: Float) {
        player?.rate = rate
    }

    func seek(to seconds: Double) {
        let target = CMTime(seconds: seconds, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
    }
}


