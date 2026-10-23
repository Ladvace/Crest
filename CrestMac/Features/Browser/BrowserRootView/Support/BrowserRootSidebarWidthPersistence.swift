import Foundation

enum BrowserRootSidebarWidthPersistence {
    static func read() -> CGFloat {
        BrowserSidebarWidthPreference.value(
            forKey: BrowserRootPreferenceKeys.sidebarWidth,
            default: BrowserChromeLayout.sidebarIdealWidth,
            allowsIconColumn: true
        )
    }

    static func write(_ width: Double) {
        UserDefaults.standard.set(width, forKey: BrowserRootPreferenceKeys.sidebarWidth)
    }
}
