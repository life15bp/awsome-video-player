import SwiftUI

struct MiniMapView: View {
    let scale: CGFloat
    let offset: CGSize

    private let mapSize: CGFloat = 140

    var body: some View {
        ZStack {
            // 全体フレーム
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                .background(
                    Color.black.opacity(0.4)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                )

            // 現在の表示範囲
            if scale > 1.01 {
                let visibleWidth = mapSize / scale
                let visibleHeight = mapSize / scale

                let clampedOffsetX = max(min(offset.width, mapSize / 2 - visibleWidth / 2), -mapSize / 2 + visibleWidth / 2)
                let clampedOffsetY = max(min(offset.height, mapSize / 2 - visibleHeight / 2), -mapSize / 2 + visibleHeight / 2)

                Rectangle()
                    .stroke(Color.white, lineWidth: 1.5)
                    .frame(width: visibleWidth, height: visibleHeight)
                    .offset(x: clampedOffsetX / scale, y: clampedOffsetY / scale)
            }
        }
        .frame(width: mapSize, height: mapSize)
    }
}

