import SwiftUI

enum BrowserChromeLayout {
    static let sidebarTitlebarHeight: CGFloat = 48
    static let sidebarNavigationControlHitTarget: CGFloat = 30
    static let sidebarNavigationSymbolPointSize: CGFloat = 15
    static let sidebarNavigationTrailingInset = CrestSpacing.medium
    static let addressEditingRingWidth: CGFloat = 0.5
    static let addressHeight: CGFloat = 36
    static let addressCornerRadius = CrestRadius.compact
    static let sidebarMinimumWidth: CGFloat = 200
    static let sidebarIdealWidth: CGFloat = 289
    static let sidebarMaximumWidth: CGFloat = 380
    /// How wide a Mac sidebar is as a column of tab icons, which it snaps to
    /// when narrowed well past its minimum.
    static let sidebarIconColumnWidth: CGFloat = 76
    static let pageFrameInset = CrestSpacing.small
    /// A page's corner where there is no window corner to follow: full screen,
    /// iPhone and iPad.
    static let pageCornerRadius: CGFloat = 13
    static let pageBrandSeamWidth: CGFloat = 1.5

    /// `width` within the sidebar's range, or the icon column's width when
    /// the sidebar may become one and `width` is nearer that than the
    /// minimum.
    static func clampedSidebarWidth(_ width: CGFloat, allowsIconColumn: Bool = false) -> CGFloat {
        if allowsIconColumn, width < (sidebarIconColumnWidth + sidebarMinimumWidth) / 2 {
            return sidebarIconColumnWidth
        }
        return min(max(width, sidebarMinimumWidth), sidebarMaximumWidth)
    }

    /// Whether a sidebar `width` wide shows only its tabs' icons.
    static func showsIconColumn(atSidebarWidth width: CGFloat) -> Bool {
        width < sidebarMinimumWidth
    }

    static func pageFrameInsets(
        adjoinsLeadingSidebar: Bool
    ) -> EdgeInsets {
        EdgeInsets(
            top: pageFrameInset,
            leading: adjoinsLeadingSidebar ? 0 : pageFrameInset,
            bottom: pageFrameInset,
            trailing: pageFrameInset
        )
    }
}
