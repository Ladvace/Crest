import AppKit
import SwiftUI

/// Reports how far into the view it sits behind the window's close, minimize
/// and zoom buttons reach, so a control placed beside them starts after them.
/// Nothing when the buttons don't cover the view, such as with the sidebar
/// docked on the window's other edge.
struct BrowserWindowButtonsClearance: NSViewRepresentable {
    /// Receives the width the buttons cover from the view's leading edge.
    let changed: (CGFloat) -> Void

    func makeNSView(context: Context) -> MeasuringView {
        let view = MeasuringView()
        view.changed = changed
        return view
    }

    func updateNSView(_ view: MeasuringView, context: Context) {
        view.changed = changed
        view.measure()
    }

    final class MeasuringView: NSView {
        var changed: (CGFloat) -> Void = { _ in }
        private var reported: CGFloat?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            measure()
        }

        override func layout() {
            super.layout()
            measure()
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        /// The width the buttons cover, reported when it changes.
        func measure() {
            guard let window, let zoom = window.standardWindowButton(.zoomButton),
                let buttons = zoom.superview, !zoom.isHidden
            else { return report(0) }
            let zoomFrame = buttons.convert(zoom.frame, to: nil)
            let ownFrame = convert(bounds, to: nil)
            let overlapsVertically = zoomFrame.maxY > ownFrame.minY && zoomFrame.minY < ownFrame.maxY
            let reaches = zoomFrame.maxX - ownFrame.minX
            report(overlapsVertically && reaches > 0 && zoomFrame.minX < ownFrame.maxX ? reaches : 0)
        }

        private func report(_ width: CGFloat) {
            guard width != reported else { return }
            reported = width
            let changed = changed
            DispatchQueue.main.async { changed(width) }
        }
    }
}
