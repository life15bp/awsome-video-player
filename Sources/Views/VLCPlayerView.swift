import SwiftUI
import AppKit
import VLCKitSPM

/// VLC で再生するための NSView。drawable に設定して VLCMediaPlayer に渡す。
final class VLCPlayerHostView: NSView {
    override var wantsUpdateLayer: Bool { true }
    override func makeBackingLayer() -> CALayer { CALayer() }
}

/// MKV など AVPlayer で再生できない形式を VLC で再生する View
struct VLCPlayerView: NSViewRepresentable {
    let url: URL
    let onPlayerReady: (VLCMediaPlayer) -> Void

    func makeNSView(context: Context) -> NSView {
        let hostView = VLCPlayerHostView(frame: .zero)
        hostView.wantsLayer = true

        let media = VLCMedia(url: url)
        let player = VLCMediaPlayer()
        player.media = media
        player.drawable = hostView

        context.coordinator.player = player
        context.coordinator.hostView = hostView

        DispatchQueue.main.async {
            onPlayerReady(player)
            player.play()
        }

        return hostView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.hostView?.frame = nsView.bounds
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var player: VLCMediaPlayer?
        weak var hostView: NSView?
        deinit {
            player?.stop()
        }
    }
}
