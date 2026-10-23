import SwiftUI

struct BrowserSidebarResizeHandle: View {
    @Binding var width: CGFloat
    var onResizeEnded: (CGFloat) -> Void = { _ in }
    var edge: HorizontalEdge = .leading
    /// Whether narrowing far enough snaps the sidebar to a column of icons.
    var allowsIconColumn = false

    @Environment(\.layoutDirection) private var layoutDirection
    @State private var dragStartWidth: CGFloat?
    @State private var isActive = false
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Color.clear
            .frame(width: BrowserSidebarResizeHandleMetrics.hitWidth)
            .contentShape(.rect)
            .modifier(BrowserPlatformColumnResizePointerModifier())
            .overlay(alignment: edge == .leading ? .leading : .trailing) {
                // A strip down the gutter before the page, lit while the
                // pointer rests on the edge and stronger while it drags. It is
                // placed from the side the sidebar is on.
                RoundedRectangle(cornerRadius: BrowserSidebarResizeHandleMetrics.indicatorWidth / 2)
                    .fill(.primary.opacity(indicatorOpacity))
                    .frame(width: BrowserSidebarResizeHandleMetrics.indicatorWidth)
                    .padding(.vertical, BrowserChromeLayout.pageFrameInset)
                    .padding(edge == .leading ? .leading : .trailing, Self.indicatorOffset)
                    .accessibilityHidden(true)
            }
            .onHover { isHovering = $0 }
            .animation(
                isHovering || isActive ? nil : CrestMotion.hoverRelease.unlessReducingMotion(reduceMotion),
                value: isHovering || isActive
            )
            .gesture(
                // The handle moves as width changes; measure in stationary coordinates.
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged(resize)
                    .onEnded(endResize)
            )
            .accessibilityLabel("Resize Sidebar")
            .accessibilityValue("\(Int(width.rounded())) points")
            .accessibilityAdjustableAction(adjustWidth)
    }

    /// How far the strip sits from the handle's sidebar side.
    private static var indicatorOffset: CGFloat {
        BrowserSidebarResizeHandleMetrics.sidebarReach - BrowserSidebarResizeHandleMetrics.indicatorInset
            - BrowserSidebarResizeHandleMetrics.indicatorWidth / 2
    }

    private var indicatorOpacity: Double {
        isActive
            ? BrowserSidebarResizeHandleMetrics.activeIndicatorOpacity
            : isHovering ? BrowserSidebarResizeHandleMetrics.hoverIndicatorOpacity : 0
    }

    private func resize(_ value: DragGesture.Value) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            let start = dragStartWidth ?? width
            dragStartWidth = start
            isActive = true
            width = BrowserChromeLayout.clampedSidebarWidth(
                start
                    + layoutDirection.sidebarResizeDelta(value.translation.width) * (edge == .leading ? 1 : -1),
                allowsIconColumn: allowsIconColumn
            )
        }
    }

    private func endResize(_ value: DragGesture.Value) {
        resize(value)
        dragStartWidth = nil
        isActive = false
        onResizeEnded(width)
    }

    private func adjustWidth(_ direction: AccessibilityAdjustmentDirection) {
        let delta: CGFloat
        switch direction {
        case .increment:
            delta = BrowserSidebarResizeHandleMetrics.accessibilityStep
        case .decrement:
            delta = -BrowserSidebarResizeHandleMetrics.accessibilityStep
        @unknown default:
            delta = 0
        }
        guard delta != 0 else { return }
        width = BrowserChromeLayout.clampedSidebarWidth(width + delta, allowsIconColumn: allowsIconColumn)
        onResizeEnded(width)
    }
}
