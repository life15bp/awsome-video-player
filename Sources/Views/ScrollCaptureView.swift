import SwiftUI
import AppKit

struct ScrollCaptureView<Content: View>: NSViewRepresentable {
    let content: Content
    /// (deltaX, deltaY, modifierFlags) — ズームは ⌘ 押下時のみ行う想定
    let onScroll: (CGFloat, CGFloat, NSEvent.ModifierFlags) -> Void

    init(onScroll: @escaping (CGFloat, CGFloat, NSEvent.ModifierFlags) -> Void, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.onScroll = onScroll
    }

    func makeNSView(context: Context) -> NSHostingView<Content> {
        let hostingView = HostingScrollView(rootView: content, onScroll: onScroll)
        return hostingView
    }

    func updateNSView(_ nsView: NSHostingView<Content>, context: Context) {
        if let hostingView = nsView as? HostingScrollView<Content> {
            hostingView.rootView = content
        } else {
            nsView.rootView = content
        }
    }

    private final class HostingScrollView<RootView: View>: NSHostingView<RootView> {
        private let onScroll: (CGFloat, CGFloat, NSEvent.ModifierFlags) -> Void

        init(rootView: RootView, onScroll: @escaping (CGFloat, CGFloat, NSEvent.ModifierFlags) -> Void) {
            self.onScroll = onScroll
            super.init(rootView: rootView)
        }

        @MainActor @preconcurrency required init(rootView: RootView) {
            self.onScroll = { _, _, _ in }
            super.init(rootView: rootView)
        }

        required init?(coder: NSCoder) {
            self.onScroll = { _, _, _ in }
            super.init(coder: coder)
        }

        override func scrollWheel(with event: NSEvent) {
            onScroll(event.scrollingDeltaX, event.scrollingDeltaY, event.modifierFlags)
        }
    }
}

