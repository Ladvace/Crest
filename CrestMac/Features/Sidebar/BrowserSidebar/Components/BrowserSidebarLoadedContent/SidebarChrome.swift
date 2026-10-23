import SwiftUI

/// The window's address and navigation stay in place while Space contents move
/// underneath. Their native field and popover identities belong to this leaf.
struct SidebarChrome: View {
    let context: BrowserSidebarContext
    let pages: BrowserPagePool
    let address: Binding<String>
    let isAddressEditing: Binding<Bool>
    let addressFocusRequest: Int
    let activateAddress: () -> Void
    let submitAddress: () -> Void
    let commandSurfaceNamespace: Namespace.ID
    let commandPaletteHandoff: BrowserCommandPaletteHandoff
    let sidebarToggleAction: BrowserSidebarToggleAction
    let toggleSidebar: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.browserChromeAppearance) private var appearance
    /// How far the window's own buttons reach into the navigation strip.
    @State private var windowButtonsWidth: CGFloat = 0
    /// Whether the strip holds the toggle beside the navigation, past the
    /// window's buttons. Kept as the answer alone, so resizing the sidebar
    /// redraws the chrome only when the answer changes.
    @State private var showsSidebarToggle = true

    /// The room back, forward and reload take, and the sidebar toggle beside
    /// them; the toggle steps aside once the strip can't hold both past the
    /// window's buttons, and ⌘S still toggles the sidebar.
    private static let navigationWidth: CGFloat = 120
    private static let toggleWidth: CGFloat = 36

    private func holdsSidebarToggle(stripWidth: CGFloat) -> Bool {
        stripWidth - windowButtonsWidth >= Self.navigationWidth + Self.toggleWidth
    }

    var body: some View {
        if let space = selectedSpace {
            let isLocked = context.spaceAccess.isLocked(space)

            VStack(spacing: 0) {
                BrowserSidebarNavigationControls(
                    port: BrowserSidebarNavigationPort(
                        pages: pages, browser: context.browser, showHistory: context.chromeActions.presentHistory),
                    capabilities: context.capabilities,
                    leadingAccessory: {
                        // Beside the window's own buttons, as Arc keeps it.
                        if showsSidebarToggle {
                            Button(
                                sidebarToggleAction.title,
                                systemImage: appearance.sidebarOnRight ? "sidebar.right" : "sidebar.left",
                                action: toggleSidebar
                            )
                            .accessibilityIdentifier("browser-sidebar-toggle")
                            .help(Text("\(Text(sidebarToggleAction.title)) (⌘S)"))
                            .padding(.leading, windowButtonsWidth > 0 ? windowButtonsWidth + CrestSpacing.small : 0)
                        }
                    }
                )
                .contentTransition(.opacity)
                .background {
                    // Only the empty navigation-strip background acts as the
                    // title bar. Controls and tab gestures keep their input.
                    BrowserWindowTitleBarSurface()
                }
                .background { BrowserWindowButtonsClearance { windowButtonsWidth = $0 } }
                .onGeometryChange(for: Bool.self) {
                    holdsSidebarToggle(stripWidth: $0.size.width)
                } action: {
                    showsSidebarToggle = $0
                }
                // Another tab's history shows at once, as every browser switches
                // tabs; a fade on each switch redraws the strip every frame.
                .animation(nil, value: pages.activeTabID)
                .animation(
                    SpacePagerSettlement.standardAnimation.unlessReducingMotion(reduceMotion),
                    value: [pages.canGoBack, pages.canGoForward, pages.activePage?.live.isLoading == true]
                )

                if context.utilityPresentation.surface == nil {
                    SpaceSidebarAddressBand(
                        browser: context.browser,
                        space: space,
                        offersSiteControls: !context.browser.isDeleting(space.id),
                        selectedTabID: context.browser.selectedTabID(in: space.id),
                        pages: pages,
                        capabilities: context.capabilities,
                        address: address,
                        isAddressEditing: isAddressEditing,
                        addressFocusRequest: addressFocusRequest,
                        activateAddress: activateAddress,
                        submitAddress: submitAddress,
                        commandSurfaceNamespace: commandSurfaceNamespace,
                        commandPaletteHandoff: commandPaletteHandoff,
                        siteControlPresentationChanged: {
                            context.utilityPresentation.setSiteControlPresented($0)
                        },
                        siteControlContextMenuPresentationChanged: {
                            context.utilityPresentation.setSiteControlContextMenuPresented($0)
                        },
                        bookmarksRequest: context.utilityPresentation.bookmarksRequest
                    )
                }
            }
            .environment(
                \.colorScheme,
                space.settings.look.foregroundTone.colorScheme
            )
            .modifier(SpaceForegroundBlend(spaces: context.availableSpaces, selectedSpaceID: space.id))
            .blur(radius: isLocked ? BrowserSidebarMetrics.lockedSpaceBlurRadius : 0)
            .redacted(reason: isLocked ? .placeholder : [])
            .allowsHitTesting(!isLocked)
            .accessibilityHidden(isLocked)
        }
    }

    /// The Space the window shows, unless it is being deleted.
    private var selectedSpace: SpaceModel? {
        context.browser.shownSpace
    }
}
