import SwiftUI

/// The sidebar narrowed to a column of icons, as Arc and Zen narrow theirs:
/// the Space's pinned tabs, a dot, then every other tab in sidebar order,
/// folders and splits opened out, each named beside it under the pointer.
/// Clicking one shows it. A locked Space shows none of its tabs until it is
/// unlocked, as the full sidebar keeps them hidden. A small search field at the top widens the sidebar
/// and opens the address; the Spaces and everything else wait for the
/// sidebar to widen again.
struct BrowserSidebarIconColumn: View {
    // MARK: - Static Variables

    private static let iconSize: CGFloat = 18
    private static let slotSize = CGSize(width: 44, height: 36)
    private static let dividerSize: CGFloat = 4

    // MARK: - Variables

    let context: BrowserSidebarContext
    let pages: BrowserPagePool
    let openNewTab: () -> Void
    /// Widens the sidebar and opens the address, and with it a locked
    /// Space's unlock.
    let search: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // The window's own controls sit in this band.
            Color.clear.frame(height: BrowserChromeLayout.sidebarTitlebarHeight)
            BrowserSidebarIconColumnSearch(size: Self.slotSize, search: search)
            if let space = context.browser.shownSpace, !context.spaceAccess.isLocked(space) {
                ScrollView(.vertical) {
                    column(space)
                        .padding(.vertical, CrestSpacing.small)
                        .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.never)
            } else {
                Spacer(minLength: 0)
            }
            Button(action: openNewTab) {
                Image(systemName: "plus")
                    .font(.system(size: BrowserChromeLayout.sidebarNavigationSymbolPointSize, weight: .medium))
            }
            .buttonStyle(CrestChromeButtonStyle())
            .browserFloatingHoverLabel(Text("New Tab"))
            .accessibilityLabel("New Tab")
            .padding(.vertical, CrestSpacing.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(context.browser.shownSpace?.settings.name ?? "Browser") Space")
    }

    // MARK: - Actions - Building

    @ViewBuilder private func column(_ space: SpaceModel) -> some View {
        let pinned = tabs(in: space.sidebar.section(.pinned), of: space)
        let others = [TabPlacement.saved, .current].flatMap { tabs(in: space.sidebar.section($0), of: space) }
        // Lazily, so a Space with hundreds of tabs builds only the icons in view.
        LazyVStack(spacing: CrestSpacing.extraSmall) {
            ForEach(pinned) { icon($0, in: space) }
            if !pinned.isEmpty, !others.isEmpty {
                Circle()
                    .fill(.secondary)
                    .frame(width: Self.dividerSize, height: Self.dividerSize)
                    .padding(.vertical, CrestSpacing.small)
                    .accessibilityHidden(true)
            }
            ForEach(others) { icon($0, in: space) }
        }
    }

    private func icon(_ tab: TabStateModel, in space: SpaceModel) -> some View {
        BrowserSidebarIconColumnTab(
            tab: tab, favicons: context.browser.core.state.favicons, profileID: space.profileID,
            isSelected: context.browser.windowModel?.shownTabIDs.contains(tab.id) == true,
            iconSize: Self.iconSize, slotSize: Self.slotSize
        ) {
            context.browser.selectTab(tab.id)
            pages.select()
        }
    }

    /// The tabs `list` shows, in order, with each folder's and split's tabs
    /// in its place.
    private func tabs(in list: SidebarListModel, of space: SpaceModel) -> [TabStateModel] {
        list.rows.flatMap { row -> [TabStateModel] in
            if row.kind.opensList { return tabs(in: space.sidebar.inside(row.id), of: space) }
            let ids = row.kind.groupsTabs ? row.members : [row.id]
            return ids.compactMap { space.tabs.model($0) }
        }
    }
}

/// One tab in the icon column: its icon on the sidebar's interactive surface,
/// named beside it under the pointer.
private struct BrowserSidebarIconColumnTab: View {
    let tab: TabStateModel
    let favicons: FaviconAssets
    let profileID: UUID
    let isSelected: Bool
    let iconSize: CGFloat
    let slotSize: CGSize
    let select: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: select) {
            TabStateFaviconView(tab: tab, favicons: favicons, profileID: profileID, size: iconSize)
                .frame(width: slotSize.width, height: slotSize.height)
                .crestInteractiveSurface(isSelected: isSelected, isHovering: isHovering)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .browserFloatingHoverLabel(Text(tab.shownTitle))
        .accessibilityLabel(Text(tab.shownTitle))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The address field as the icon column keeps it: a magnifier on the field's
/// surface that widens the sidebar and opens the address.
private struct BrowserSidebarIconColumnSearch: View {
    let size: CGSize
    let search: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: search) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: BrowserChromeLayout.sidebarNavigationSymbolPointSize, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: size.width, height: size.height)
                .crestInteractiveSurface(isSelected: false, isHovering: isHovering, showsRestingSurface: true)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .browserFloatingHoverLabel(Text("Search or Enter Address"))
        .accessibilityLabel("Search or Enter Address")
    }
}
