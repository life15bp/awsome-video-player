import SwiftUI
import AVKit
import AppKit

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

struct PlayerView: View {
    @EnvironmentObject private var libraryViewModel: LibraryViewModel
    @EnvironmentObject private var playerViewModel: PlayerViewModel
    @State private var lastDragOffset: CGSize = .zero

    var body: some View {
        VStack(spacing: 0) {
            if let player = playerViewModel.player {
                ZStack {
                    ZStack(alignment: .bottomTrailing) {
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

                        if playerViewModel.viewport.scale > 1.01 {
                            MiniMapView(
                                scale: playerViewModel.viewport.scale,
                                offset: playerViewModel.viewport.offset
                            )
                            .padding(12)
                        }
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
                    .padding()
                }

                playbackBar
            } else {
                Text("No video selected")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(FullScreenWindowEnabler())
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

            Slider(
                value: Binding(
                    get: { playerViewModel.progress },
                    set: { playerViewModel.seek(to: $0) }
                ),
                in: 0...1
            )

            Text(playerViewModel.formattedTime(playerViewModel.durationSeconds))
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(width: 44, alignment: .leading)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
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

