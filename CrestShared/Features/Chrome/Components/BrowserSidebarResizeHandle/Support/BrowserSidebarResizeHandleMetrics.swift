import CoreGraphics

enum BrowserSidebarResizeHandleMetrics {
    /// Wide enough to find without aiming, reaching across the sidebar's
    /// gutter and only a little into its rows and the page.
    static let hitWidth: CGFloat = 20
    /// How far the grab area reaches into the sidebar from its edge.
    static let sidebarReach: CGFloat = 12
    /// The strip that lights up in the gutter before the page, and how far
    /// its middle sits inside the sidebar's edge.
    static let indicatorWidth: CGFloat = 5
    static let indicatorInset: CGFloat = 4
    static let hoverIndicatorOpacity = 0.16
    static let activeIndicatorOpacity = 0.22
    static let accessibilityStep: CGFloat = 20
}
