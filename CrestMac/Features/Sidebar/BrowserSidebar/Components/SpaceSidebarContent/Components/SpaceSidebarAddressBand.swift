import SwiftUI

/// Fixed address controls. The pager owns the changing extension-strip seam
/// so semantic selection cannot resize the viewport during a Space transition.
struct SpaceSidebarAddressBand: View {
    let browser: BrowserStore
    let space: SpaceModel
    /// Whether the site controls act for `space`; they offer nothing while it
    /// is being deleted.
    let offersSiteControls: Bool
    /// The tab this window shows in `space`.
    let selectedTabID: UUID?
    let pages: BrowserPagePool
    let capabilities: BrowserInteractionCapabilities
    let address: Binding<String>
    let isAddressEditing: Binding<Bool>
    let addressFocusRequest: Int
    let activateAddress: () -> Void
    let submitAddress: () -> Void
    let commandSurfaceNamespace: Namespace.ID
    let commandPaletteHandoff: BrowserCommandPaletteHandoff
    let siteControlPresentationChanged: (Bool) -> Void
    let siteControlContextMenuPresentationChanged: (Bool) -> Void
    /// The latest request to open the bookmarks, from the menu or a shortcut.
    let bookmarksRequest: BrowserBookmarksRequest?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Whether the band is too narrow for every control beside the address.
    /// Kept as the answer alone, so resizing redraws the band only when it
    /// changes.
    @State private var isCompact = false

    /// Below this width the address keeps its room, as Arc keeps it: the
    /// security mark and the copy-link control step out, and the bookmarks
    /// control keeps no width but stays where its shortcut and popover reach
    /// it. The site controls stay, since permission prompts open from them.
    private static let compactWidth: CGFloat = 240

    var body: some View {
        BrowserSidebarAddressField(configuration: addressConfiguration) {
            if let siteControl, !isCompact {
                BrowserAddressSecurityButton(
                    page: siteControl.page,
                    isSecure: isSecure
                )
            }
        } trailingAccessory: {
            HStack(spacing: 0) {
                BrowserBookmarksButton(
                    browser: browser, space: space, page: bookmarkPage, request: bookmarksRequest,
                    presentationChanged: siteControlPresentationChanged
                )
                .frame(width: isCompact ? 0 : nil)
                .opacity(isCompact ? 0 : 1)
                .allowsHitTesting(!isCompact)
                .accessibilityHidden(isCompact)
                if let siteControl {
                    if !isCompact { BrowserCopyLinkButton(page: siteControl.page) }
                    BrowserSiteControlButton(configuration: siteControl)
                }
            }
        }
        .onGeometryChange(for: Bool.self) {
            $0.size.width < Self.compactWidth
        } action: {
            isCompact = $0
        }
        .contentTransition(.opacity)
        .animation(
            SpacePagerSettlement.standardAnimation.unlessReducingMotion(reduceMotion),
            value: isAddressEditing.wrappedValue ? nil : address.wrappedValue
        )
        .padding(.horizontal, BrowserSidebarMetrics.layerInset)

    }

    private var addressConfiguration: BrowserSidebarAddressFieldConfiguration {
        BrowserSidebarAddressFieldConfiguration(
            text: address,
            isEditing: isAddressEditing,
            focusRequest: addressFocusRequest,
            isSecure: isSecure,
            progress: displayedPage?.estimatedProgress ?? 0,
            isLoading: displayedPage?.live.isLoading == true,
            hasResidentPage: displayedPage != nil,
            hasActiveSite: siteControl != nil,
            offersBookmarks: true,
            capabilities: capabilities,
            activate: activateAddress,
            submit: submitAddress,
            morphNamespace: commandSurfaceNamespace,
            spaceID: space.id,
            commandPaletteHandoff: commandPaletteHandoff,
            branding: space.settings.look
        )
    }

    /// The page the bookmarks button can bookmark: the one on show, as it
    /// spells its address and title, or the selected tab's when it has none.
    private var bookmarkPage: BrowserBookmarkPage? {
        if let page = displayedPage, let url = page.live.displayURL?.absoluteString {
            return BrowserBookmarkPage(url: url, title: page.live.title.isEmpty ? url : page.live.title)
        }
        guard let tab = selectedTab, let url = tab.url, url.hasPrefix("http") else { return nil }
        return BrowserBookmarkPage(url: url, title: tab.title.isEmpty ? url : tab.title)
    }

    private var selectedTab: TabStateModel? {
        selectedTabID.flatMap { space.tabs.model($0) }
    }

    private var displayedPage: BrowserPage? {
        guard let selectedTabID else { return nil }
        let assignment = BrowserTabRuntimeAssignment(
            tabID: selectedTabID, spaceID: space.id, profileID: space.profileID
        )
        return pages.activePage(matching: assignment)
    }

    private var isSecure: Bool {
        if let page = displayedPage { return page.live.security.isSecure }
        return selectedTab?.url.flatMap(URL.init(string:))?.scheme?.lowercased() == "https"
    }

    private var siteControl: BrowserSiteControlConfiguration? {
        guard offersSiteControls, let page = displayedPage, page.live.displayURL != nil else {
            return nil
        }
        return BrowserSiteControlConfiguration(
            browser: browser,
            page: page,
            space: space,
            selectedTabID: selectedTabID,
            permissionCenter: pages.permissionCenter,
            presentationChanged: siteControlPresentationChanged,
            contextMenuPresentationChanged:
                siteControlContextMenuPresentationChanged
        )
    }
}
