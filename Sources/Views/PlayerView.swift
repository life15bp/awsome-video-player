import SwiftUI
import AVKit

struct PlayerView: View {
    @EnvironmentObject private var playerViewModel: PlayerViewModel

    var body: some View {
        VStack {
            if let player = playerViewModel.player {
                VideoPlayer(player: player)
                    .aspectRatio(16 / 9, contentMode: .fit)
            } else {
                Text("No video selected")
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 8) {
                // シークバー
                Slider(
                    value: Binding(
                        get: { playerViewModel.progress },
                        set: { playerViewModel.seek(to: $0) }
                    ),
                    in: 0...1
                )

                // 時間表示と再生ボタン
                HStack {
                    Text(playerViewModel.formattedTime(playerViewModel.currentSeconds))
                        .font(.system(size: 12, weight: .regular, design: .monospaced))

                    Text(playerViewModel.formattedTime(playerViewModel.durationSeconds))
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("Play") {
                        playerViewModel.play()
                    }
                    Button("Pause") {
                        playerViewModel.pause()
                    }
                }
            }
            .padding(.top, 8)
        }
        .padding()
    }
}

