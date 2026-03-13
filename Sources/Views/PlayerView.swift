import SwiftUI
import AVKit
import AppKit

/// ホバー時に薄い黒のオーバーレイを出さないプレーヤー表示（AVPlayerView の controlsStyle = .none）
private struct PlainAVPlayerView: NSViewRepresentable {
    let player: AVPlayer?

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .none
        view.player = player
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}

struct PlayerView: View {
    @EnvironmentObject private var libraryViewModel: LibraryViewModel
    @EnvironmentObject private var playerViewModel: PlayerViewModel
    @State private var lastDragOffset: CGSize = .zero
    @State private var keyMonitor: Any?

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
        .onAppear {
            // スペースキー(キーコード 49)で再生/一時停止をトグル
            if keyMonitor == nil {
                keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    guard event.keyCode == 49 else { return event }
                    playerViewModel.togglePlayPause()
                    return nil
                }
            }
        }
        .onDisappear {
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
                keyMonitor = nil
            }
        }
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

        PlainAVPlayerView(player: player)
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

