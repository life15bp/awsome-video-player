import CoreGraphics

struct ViewportState {
    var scale: CGFloat = 1.0
    var offset: CGSize = .zero

    mutating func applyScale(delta: CGFloat, minScale: CGFloat = 0.3, maxScale: CGFloat = 8.0) {
        let newScale = (scale + delta).clamped(to: minScale...maxScale)
        scale = newScale
    }

    mutating func applyPan(translation: CGSize) {
        offset = translation
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

