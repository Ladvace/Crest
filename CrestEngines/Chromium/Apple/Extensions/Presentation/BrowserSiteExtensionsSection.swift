import SwiftUI

struct BrowserSiteExtensionsSection: View {
    let actions: [BrowserExtensionActionPresentation]
    let manageExtensions: () -> Void
    /// Opens the Chrome Web Store to add an extension.
    var addExtension: (() -> Void)?
    let perform: (BrowserExtensionActionPresentation, BrowserExtensionPopupAnchor?) -> Void
    let togglePinned: (BrowserExtensionActionPresentation) -> Void
    var presentMenu:
        (BrowserExtensionActionPresentation, BrowserExtensionPopupAnchor?) ->
            Void = { _, _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: CrestSpacing.medium) {
            BrowserSiteExtensionsHeader(
                manageExtensions: manageExtensions
            )
            if actions.isEmpty, addExtension == nil {
                Label(
                    "No extension actions for this page",
                    systemImage: "puzzlepiece.extension"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                actionGrid
            }
        }
    }

    private var actionGrid: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(
                    .flexible(),
                    spacing: BrowserSiteControlMetrics.extensionGridSpacing
                ),
                count: BrowserSiteControlMetrics.extensionColumnCount
            ),
            spacing: BrowserSiteControlMetrics.extensionGridSpacing
        ) {
            ForEach(actions) { action in
                BrowserSiteExtensionActionButton(
                    action: action,
                    perform: { perform(action, $0) },
                    togglePinned: { togglePinned(action) },
                    presentMenu: { presentMenu(action, $0) }
                )
            }
            if let addExtension {
                Button(action: addExtension) {
                    Image(systemName: "plus")
                        .font(.system(size: BrowserSiteControlMetrics.quickActionGlyphSize, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: BrowserSiteControlMetrics.extensionActionHeight)
                }
                .buttonStyle(
                    CrestChromeButtonStyle(controlSize: nil, cornerRadius: CrestRadius.compact, showsRestingFill: true)
                )
                .accessibilityLabel("Add Extension")
                .help("Add Extension from the Chrome Web Store")
            }
        }
    }
}
