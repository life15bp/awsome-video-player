import SwiftUI
import AVKit

struct PlayerView: View {
    @EnvironmentObject private var playerViewModel: PlayerViewModel
    @State private var lastDragOffset: CGSize = .zero

    var body: some View {
        VStack {
            if let player = playerViewModel.player {
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
            } else {
                Text("No video selected")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    @ViewBuilder
    private func videoContent(player: AVPlayer) -> some View {
        let viewport = playerViewModel.viewport

        VideoPlayer(player: player)
            .scaleEffect(viewport.scale)
            .offset(viewport.offset)
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

