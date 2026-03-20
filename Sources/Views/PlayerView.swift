import SwiftUI
import AVKit
import AppKit

/// 動画を画面いっぱいに表示（resizeAspectFill）。フルスクリーン時の左右余白解消用。
private struct AVPlayerFillView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> NSView {
        let view = PlayerLayerHostView()
        view.wantsLayer = true
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspectFill
        view.playerLayer = layer
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let host = nsView as? PlayerLayerHostView else { return }
        host.playerLayer?.player = player
        host.needsLayout = true
    }

    private class PlayerLayerHostView: NSView {
        var playerLayer: AVPlayerLayer? {
            didSet {
                oldValue?.removeFromSuperlayer()
                guard let pl = playerLayer else { return }
                layer?.addSublayer(pl)
            }
        }
        override func layout() {
            super.layout()
            if let pl = playerLayer {
                if pl.superlayer != layer { layer?.addSublayer(pl) }
                pl.frame = bounds
            }
        }
    }
}

/// プレイヤーウィンドウで緑ボタンがネイティブフルスクリーン（メニュー非表示）になるよう collectionBehavior を設定する
private struct FullScreenWindowEnabler: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView(frame: .zero)
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            applyFullScreenBehavior(to: window)
            return
        }
        DispatchQueue.main.async {
            if let w = nsView.window {
                applyFullScreenBehavior(to: w)
                return
            }
            guard let playerWindow = NSApp.windows.first(where: { $0.title == "Player" }) else { return }
            applyFullScreenBehavior(to: playerWindow)
        }
    }

    private func applyFullScreenBehavior(to window: NSWindow) {
        var behavior = window.collectionBehavior
        behavior.remove(.fullScreenNone)
        behavior.insert(.fullScreenPrimary)
        window.collectionBehavior = behavior
    }
}

/// スペースキーのホールドで 2倍速、離すと元の速度。短押しで再生/一時停止。
private struct SpaceKeyMonitorView: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @State private var monitor: Any?

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear { installMonitor() }
            .onDisappear { removeMonitor() }
    }

    private func installMonitor() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: NSEvent.EventTypeMask(arrayLiteral: .keyDown, .keyUp)) { [weak playerViewModel] event in
            guard let vm = playerViewModel else { return event }
            guard NSApp.keyWindow?.title.contains("Player") == true else { return event }
            if event.keyCode == 49 {
                if event.type == .keyDown {
                    vm.onSpaceKeyDown()
                    return nil
                }
                if event.type == .keyUp {
                    vm.onSpaceKeyUp()
                    return nil
                }
                return event
            }
            if event.type == .keyDown {
                let shift = event.modifierFlags.contains(.shift)
                if event.keyCode == 123 {
                    if shift { vm.stepBackward5Sec() } else { vm.stepBackwardFrame() }
                    return nil
                }
                if event.keyCode == 124 {
                    if shift { vm.stepForward5Sec() } else { vm.stepForwardFrame() }
                    return nil
                }
            }
            return event
        }
    }

    private func removeMonitor() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
    }
}

/// ウィンドウのフルスクリーン入退を検知して Binding を更新する
private struct FullScreenObserver: NSViewRepresentable {
    @Binding var isFullScreen: Bool

    func makeNSView(context: Context) -> NSView {
        let v = NSView(frame: .zero)
        return v
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard context.coordinator.observers.isEmpty else { return }
        guard let window = nsView.window else { return }
        let token1 = NotificationCenter.default.addObserver(
            forName: NSWindow.didEnterFullScreenNotification,
            object: window,
            queue: .main
        ) { [weak nsView] _ in
            guard nsView?.window != nil else { return }
            DispatchQueue.main.async { isFullScreen = true }
        }
        let token2 = NotificationCenter.default.addObserver(
            forName: NSWindow.willExitFullScreenNotification,
            object: window,
            queue: .main
        ) { [weak nsView] _ in
            guard nsView?.window != nil else { return }
            DispatchQueue.main.async { isFullScreen = false }
        }
        context.coordinator.observers = [token1, token2]
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var observers: [NSObjectProtocol] = []
        deinit {
            observers.forEach { NotificationCenter.default.removeObserver($0) }
        }
    }
}

struct PlayerView: View {
    @EnvironmentObject private var libraryViewModel: LibraryViewModel
    @EnvironmentObject private var playerViewModel: PlayerViewModel
    @State private var lastDragOffset: CGSize = .zero
    @State private var isFullScreen = false

    /// MKV のときは VLC で再生（AVPlayer は使わない）
    private var useVLCForCurrentFile: Bool {
        guard let file = playerViewModel.currentFile else { return false }
        return file.url.pathExtension.lowercased() == "mkv"
    }

    var body: some View {
        VStack(spacing: 0) {
            if let player = playerViewModel.player {
                ZStack {
                    ZStack(alignment: .bottomTrailing) {
                        Group {
                            if isFullScreen {
                                AVPlayerFillView(player: player)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .contentShape(Rectangle())
                                    .onTapGesture { playerViewModel.togglePlayPause() }
                            } else {
                                ScrollCaptureView(onScroll: { deltaX, deltaY, modifierFlags in
                                    let commandPressed = modifierFlags.contains(.command)
                                    if commandPressed, abs(deltaY) >= abs(deltaX) {
                                        playerViewModel.zoom(byScrollDelta: deltaY)
                                    } else if abs(deltaX) > abs(deltaY) {
                                        playerViewModel.scrub(byHorizontalDelta: deltaX)
                                    }
                                }) {
                                    videoContent(player: player)
                                }
                                .aspectRatio(16 / 9, contentMode: .fit)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()

                        if playerViewModel.viewport.scale > 1.01 {
                            MiniMapView(
                                scale: playerViewModel.viewport.scale,
                                offset: playerViewModel.viewport.offset
                            )
                            .padding(8)
                        }
                    }

                    PlaybackOverlayView()
                        .environmentObject(libraryViewModel)
                        .environmentObject(playerViewModel)

                    if let errorMessage = playerViewModel.playbackError {
                        playbackErrorOverlay(message: errorMessage)
                    }

                    VStack {
                        HStack {
                            Button("★ お気に入りに追加") {
                                playerViewModel.addFavoriteAtCurrentTime()
                            }
                            Spacer()
                            Button {
                                togglePlayerFullScreen()
                            } label: {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                            }
                            .buttonStyle(.plain)
                            .help("フルスクリーン")
                        }
                        Spacer()
                    }
                    .padding(0)
                }

                playbackBar
            } else if useVLCForCurrentFile, let file = playerViewModel.currentFile {
                ZStack {
                    VLCPlayerView(url: file.url) { player in
                        playerViewModel.setVLCPlayer(player)
                    }
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .onTapGesture {
                        playerViewModel.togglePlayPause()
                    }

                    PlaybackOverlayView()
                        .environmentObject(libraryViewModel)
                        .environmentObject(playerViewModel)

                    VStack {
                        HStack {
                            Button("★ お気に入りに追加") {
                                playerViewModel.addFavoriteAtCurrentTime()
                            }
                            Spacer()
                            Button {
                                togglePlayerFullScreen()
                            } label: {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                            }
                            .buttonStyle(.plain)
                            .help("フルスクリーン")
                        }
                        Spacer()
                    }
                    .padding(0)
                }
                playbackBar
            } else {
                Text("No video selected")
                    .foregroundColor(.secondary)
            }
        }
        .padding(0)
        .background(FullScreenWindowEnabler())
        .background(FullScreenObserver(isFullScreen: $isFullScreen))
        .background(SpaceKeyMonitorView(playerViewModel: playerViewModel))
    }

    /// 再生失敗時に表示するオーバーレイ（AVPlayer 非対応形式など）。MKV はデフォルトアプリで開ける。
    private func playbackErrorOverlay(message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Text(message)
                .font(.body)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.75))
                .cornerRadius(8)
            Text("MKV などはデフォルトの動画アプリ（IINA / VLC など）で再生できます")
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
            if playerViewModel.currentFile != nil {
                Button("デフォルトのアプリで開く") {
                    playerViewModel.openCurrentFileInDefaultApp()
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.4))
    }

    /// プレイヤーウィンドウをネイティブフルスクリーン（メニュー・Dock 非表示）で切り替え
    private func togglePlayerFullScreen() {
        let window = NSApp.keyWindow
            ?? NSApp.windows.first { $0.title == "Player" || $0.title.contains("Player") }
        guard let w = window else { return }
        var behavior = w.collectionBehavior
        behavior.remove(.fullScreenNone)
        behavior.insert(.fullScreenPrimary)
        w.collectionBehavior = behavior
        w.toggleFullScreen(nil)
    }

    private var playbackBar: some View {
        HStack(spacing: 8) {
            Text(playerViewModel.formattedTime(playerViewModel.currentSeconds))
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(width: 44, alignment: .trailing)

            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    SeekBarThumbnailControl(
                        progress: playerViewModel.progress,
                        onSeek: { playerViewModel.seek(to: $0) },
                        onHoverProgress: { playerViewModel.onSeekBarHover(progress: $0) },
                        onHoverExit: { playerViewModel.onSeekBarHoverExit() }
                    )
                    .frame(height: 20)

                    if let p = playerViewModel.seekPreviewProgress,
                       let t = playerViewModel.seekPreviewTimeSeconds {
                        let tooltipW: CGFloat = 110
                        let tooltipH: CGFloat = 92
                        let rawX = CGFloat(p) * geo.size.width - tooltipW / 2
                        let clampedX = min(max(rawX, 0), max(0, geo.size.width - tooltipW))

                        VStack(spacing: 6) {
                            ZStack {
                                if let img = playerViewModel.seekPreviewThumbnail {
                                    Image(nsImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: tooltipW, height: 62)
                                        .clipped()
                                } else {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.4))
                                        .frame(width: tooltipW, height: 62)
                                }
                            }
                            Text(playerViewModel.formattedTime(t))
                                .font(.caption2.monospacedDigit())
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.bottom, 6)
                        }
                        .frame(width: tooltipW, height: tooltipH)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(8)
                        .offset(x: clampedX, y: -tooltipH - 8)
                    }
                }
            }
            .frame(height: 44)
            .frame(maxWidth: .infinity)

            Text(playerViewModel.formattedTime(playerViewModel.durationSeconds))
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(width: 44, alignment: .leading)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 0)
    }

    @ViewBuilder
    private func videoContent(player: AVPlayer) -> some View {
        let viewport = playerViewModel.viewport

        VideoPlayer(player: player)
            .scaleEffect(viewport.scale)
            .offset(viewport.offset)
            .contentShape(Rectangle())
            .onTapGesture {
                playerViewModel.togglePlayPause()
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let combined = CGSize(
                            width: lastDragOffset.width + value.translation.width,
                            height: lastDragOffset.height + value.translation.height
                        )
                        playerViewModel.pan(by: combined)
                    }
                    .onEnded { _ in
                        lastDragOffset = playerViewModel.viewport.offset
                    }
            )
    }
}

/// シークバー上のマウス移動（hover）とドラッグ（seek）を拾う NSView。
/// 進行度（0...1）を外部へコールバックする。
private struct SeekBarThumbnailControl: NSViewRepresentable {
    var progress: Double
    var onSeek: (Double) -> Void
    var onHoverProgress: (Double) -> Void
    var onHoverExit: () -> Void

    func makeNSView(context: Context) -> SeekBarHoverNSView {
        let v = SeekBarHoverNSView()
        v.coordinator = context.coordinator
        v.progress = progress
        return v
    }

    func updateNSView(_ nsView: SeekBarHoverNSView, context: Context) {
        nsView.progress = progress
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSeek: onSeek, onHoverProgress: onHoverProgress, onHoverExit: onHoverExit)
    }

    final class Coordinator {
        let onSeek: (Double) -> Void
        let onHoverProgress: (Double) -> Void
        let onHoverExit: () -> Void

        init(onSeek: @escaping (Double) -> Void,
             onHoverProgress: @escaping (Double) -> Void,
             onHoverExit: @escaping () -> Void) {
            self.onSeek = onSeek
            self.onHoverProgress = onHoverProgress
            self.onHoverExit = onHoverExit
        }
    }
}

private final class SeekBarHoverNSView: NSView {
    var coordinator: SeekBarThumbnailControl.Coordinator!

    var progress: Double = 0 {
        didSet { needsDisplay = true }
    }

    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            self.removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [.inVisibleRect, .mouseMoved, .activeAlways, .enabledDuringMouseDrag]
        trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        if let trackingArea { addTrackingArea(trackingArea) }
    }

    private func progress(for point: NSPoint) -> Double {
        guard bounds.width > 0 else { return 0 }
        let x = min(max(point.x, 0), bounds.width)
        return x / bounds.width
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard bounds.width > 0, bounds.height > 0 else { return }

        let trackHeight: CGFloat = 4
        let y = bounds.midY - trackHeight / 2
        let trackRect = NSRect(x: 0, y: y, width: bounds.width, height: trackHeight)

        let bgColor = NSColor.controlAccentColor.withAlphaComponent(0.25)
        bgColor.setFill()
        NSBezierPath(
            roundedRect: trackRect,
            xRadius: trackHeight / 2,
            yRadius: trackHeight / 2
        ).fill()

        let clamped = min(max(progress, 0), 1)
        let filledWidth = bounds.width * clamped
        if filledWidth > 0 {
            let filledRect = NSRect(x: 0, y: y, width: filledWidth, height: trackHeight)
            NSColor.controlAccentColor.setFill()
            NSBezierPath(
                roundedRect: filledRect,
                xRadius: trackHeight / 2,
                yRadius: trackHeight / 2
            ).fill()
        }

        // ノブ
        let knobRadius: CGFloat = 6
        let knobX = bounds.width * clamped
        let knobRect = NSRect(
            x: knobX - knobRadius,
            y: bounds.midY - knobRadius,
            width: knobRadius * 2,
            height: knobRadius * 2
        )
        NSColor.windowFrameTextColor.withAlphaComponent(0.9).setFill()
        NSBezierPath(ovalIn: knobRect).fill()
    }

    override func mouseMoved(with event: NSEvent) {
        let p = progress(for: convert(event.locationInWindow, from: nil))
        coordinator.onHoverProgress(p)
    }

    override func mouseDown(with event: NSEvent) {
        let p = progress(for: convert(event.locationInWindow, from: nil))
        coordinator.onSeek(p)
        coordinator.onHoverProgress(p)
    }

    override func mouseDragged(with event: NSEvent) {
        let p = progress(for: convert(event.locationInWindow, from: nil))
        coordinator.onSeek(p)
        coordinator.onHoverProgress(p)
    }

    override func mouseExited(with event: NSEvent) {
        coordinator.onHoverExit()
    }
}

