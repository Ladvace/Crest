import SwiftUI

struct BrowserPinnedExtensionStripContent: View {
    // MARK: - Variables

    let actions: [BrowserExtensionActionPresentation]
    let perform: (BrowserExtensionActionPresentation, BrowserExtensionPopupAnchor?) -> Void
    var prepare: (BrowserExtensionActionPresentation) -> Void = { _ in }
    var presentMenu:
        (BrowserExtensionActionPresentation, BrowserExtensionPopupAnchor?) ->
            Void = { _, _ in }

    var body: some View {
        BrowserPinnedExtensionActionList(
            actions: actions,
            perform: perform,
            prepare: prepare,
            presentMenu: presentMenu
        )
        .padding(.horizontal, BrowserSidebarMetrics.layerInset)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pinned Extensions")
        .accessibilityIdentifier("browser-pinned-extensions")
    }
}
