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

            HStack {
                Button("Play") {
                    playerViewModel.play()
                }
                Button("Pause") {
                    playerViewModel.pause()
                }
                Spacer()
            }
            .padding(.top, 8)
        }
        .padding()
    }
}

