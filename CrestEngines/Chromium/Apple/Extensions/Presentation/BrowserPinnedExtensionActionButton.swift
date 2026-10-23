import SwiftUI

struct BrowserPinnedExtensionActionButton: View {
    // MARK: - Static Variables

    private static let tileHeight: CGFloat = 28
    private static let glyphSize: CGFloat = 16

    // MARK: - Variables

    let action: BrowserExtensionActionPresentation
    let perform: (BrowserExtensionPopupAnchor?) -> Void
    var prepare: () -> Void = {}
    var presentMenu: (BrowserExtensionPopupAnchor?) -> Void = { _ in }

    @State private var isHovering = false
    @State private var popupAnchor: BrowserExtensionPopupAnchor?

    var body: some View {
        // Each extension is a small tile of its own, like a pinned site.
        anchoredButton
            .crestInteractiveSurface(
                isSelected: false, isHovering: isHovering, cornerRadius: BrowserSidebarMetrics.layerCornerRadius(),
                showsRestingSurface: true
            )
            .contentShape(.rect)
            .onHover(perform: hoverChanged)
    }

    private var anchoredButton: some View {
        actionButton
            .frame(maxWidth: .infinity)
            .frame(height: Self.tileHeight)
            .background {
                BrowserExtensionPopupAnchorReader(
                    popupAnchor: $popupAnchor,
                    site: .tile(action.id)
                )
            }
            .overlay {
                BrowserExtensionContextMenuTrigger(presentMenu: presentMenu)
            }
    }

    private var actionButton: some View {
        Button(action: performAction) {
            Group {
                if action.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityHidden(true)
                } else {
                    BrowserExtensionActionArtwork(
                        action: action,
                        glyphSize: Self.glyphSize
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!action.isEnabled || action.isLoading)
        .accessibilityLabel(action.displayName)
        .accessibilityValue(
            action.isLoading ? "Loading…" : ""
        )
        .accessibilityIdentifier("pinned-extension-action-\(action.id)")
        .help(Text(verbatim: action.displayName))
    }

    private func hoverChanged(_ isHovering: Bool) {
        self.isHovering = isHovering
        guard isHovering, action.isEnabled, !action.isLoading else { return }
        prepare()
    }

    private func performAction() {
        perform(popupAnchor)
    }
}
