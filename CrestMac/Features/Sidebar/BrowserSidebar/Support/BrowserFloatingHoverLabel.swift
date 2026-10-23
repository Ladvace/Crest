import AppKit
import SwiftUI

/// A control's name beside it, on the side toward the window's middle, where
/// the page is, while the pointer is over it, drawn in a small child window so it shows above the page.
/// AppKit composites a page's view above anything SwiftUI draws in the same
/// window, so a label reaching over the page from the sidebar would be cut
/// off; a child window ordered above its parent paints above all of it. The
/// window takes no clicks and never becomes key.
struct BrowserFloatingHoverLabel: ViewModifier {
    // MARK: - Variables

    let title: Text
    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Actions - Body

    func body(content: Content) -> some View {
        content
            .onHover { isHovering = $0 }
            .background {
                BrowserFloatingHoverLabelAnchor(
                    label: CrestHoverLabelCapsule(title: title).environment(\.colorScheme, colorScheme),
                    isShown: isHovering)
            }
    }
}

extension View {
    /// Names the control beside it, above the page, while the pointer is over
    /// it.
    func browserFloatingHoverLabel(_ title: Text) -> some View {
        modifier(BrowserFloatingHoverLabel(title: title))
    }
}

/// Marks where the control is, and shows the label's window beside it.
private struct BrowserFloatingHoverLabelAnchor<Label: View>: NSViewRepresentable {
    let label: Label
    let isShown: Bool

    func makeNSView(context: Context) -> BrowserFloatingHoverLabelView<Label> {
        BrowserFloatingHoverLabelView()
    }

    func updateNSView(_ view: BrowserFloatingHoverLabelView<Label>, context: Context) {
        view.show(isShown ? label : nil)
    }

    static func dismantleNSView(_ view: BrowserFloatingHoverLabelView<Label>, coordinator: ()) {
        view.show(nil)
    }
}

/// The control's place in its window, which owns the label's child window
/// while the label shows.
private final class BrowserFloatingHoverLabelView<Label: View>: NSView {
    // MARK: - Static Variables

    /// How far past the control's edge the label sits.
    private static var gap: CGFloat { 8 }

    // MARK: - Variables

    private var panel: NSPanel?

    // MARK: - Actions - Showing

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { show(nil) }
    }

    /// Shows `label` beside the control, or takes it down when nil.
    func show(_ label: Label?) {
        guard let label, let parent = window else {
            if let panel {
                panel.parent?.removeChildWindow(panel)
                panel.orderOut(nil)
            }
            panel = nil
            return
        }
        let host = NSHostingView(rootView: label)
        let size = host.fittingSize
        let control = parent.convertToScreen(convert(bounds, to: nil))
        // Toward the page: right of a control in the window's left half, left
        // of one in its right half, whichever edge the sidebar docks on.
        let leadsLeft = control.midX > parent.frame.midX
        let frame = CGRect(
            x: leadsLeft ? control.minX - Self.gap - size.width : control.maxX + Self.gap,
            y: control.midY - size.height / 2, width: size.width, height: size.height)
        let panel = self.panel ?? Self.makePanel()
        panel.contentView = host
        panel.setFrame(frame, display: true)
        if panel.parent == nil { parent.addChildWindow(panel, ordered: .above) }
        panel.orderFront(nil)
        self.panel = panel
    }

    private static func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        return panel
    }
}
