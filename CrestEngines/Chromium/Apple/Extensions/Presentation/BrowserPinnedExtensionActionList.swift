import SwiftUI

struct BrowserPinnedExtensionActionList: View {
    // MARK: - Static Variables

    private static let spacing: CGFloat = 6

    /// The most tiles a row holds; more wrap onto the next row.
    private static let columns = 5

    // MARK: - Variables

    let actions: [BrowserExtensionActionPresentation]
    let perform: (BrowserExtensionActionPresentation, BrowserExtensionPopupAnchor?) -> Void
    var prepare: (BrowserExtensionActionPresentation) -> Void = { _ in }
    var presentMenu:
        (BrowserExtensionActionPresentation, BrowserExtensionPopupAnchor?) ->
            Void = { _, _ in }

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: Self.spacing), count: Self.columns),
            spacing: Self.spacing
        ) {
            ForEach(actions) { action in
                BrowserPinnedExtensionActionButton(
                    action: action,
                    perform: { perform(action, $0) },
                    prepare: { prepare(action) },
                    presentMenu: { presentMenu(action, $0) }
                )
            }
        }
    }
}
