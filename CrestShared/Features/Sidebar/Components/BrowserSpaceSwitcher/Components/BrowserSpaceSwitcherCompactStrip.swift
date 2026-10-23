import SwiftUI

/// A centred row of Space icons with the shell's accessories held clear at
/// either edge.
///
/// The row gets an explicit width from the actual strip width and the larger
/// occupied utility side, and sizes its icons to fit it.
///
/// The sidebar toggle and the lists keep to the window's edge, and the "+"
/// to the page side, whichever side the sidebar is docked on.
struct BrowserSpaceSwitcherCompactStrip: View {
    // MARK: - Variables

    let spaces: [BrowserSpaceIdentity]
    let selectedSpaceID: UUID
    let reorderState: BrowserSidebarReorderState
    let selectSpace: (UUID) -> Void
    let accessories: BrowserSpaceSwitcherAccessories
    let downloads: BrowserSpaceSwitcherDownloads

    @Environment(\.browserChromeAppearance) private var appearance
    @Environment(\.layoutDirection) private var layoutDirection

    /// The edge of the window the sidebar, and so this strip, stands against.
    private var sidebarEdge: HorizontalEdge {
        appearance.sidebarEdge(in: layoutDirection)
    }

    var body: some View {
        GeometryReader { geometry in
            let allocation = BrowserSpaceSwitcherLayout.compactStripAllocation(
                availableWidth: geometry.size.width,
                spaceCount: spaces.count,
                leadingUtilityWidth: utilityWidth(at: .leading),
                trailingUtilityWidth: utilityWidth(at: .trailing)
            )

            ZStack {
                HStack(spacing: BrowserSpaceSwitcherLayout.compactStripSpacing) {
                    accessory(at: .leading)
                        .accessibilitySortPriority(
                            BrowserSpaceSwitcherLayout.leadingUtilityAccessibilityPriority
                        )

                    Spacer()

                    accessory(at: .trailing)
                        .accessibilitySortPriority(
                            BrowserSpaceSwitcherLayout.trailingUtilityAccessibilityPriority
                        )
                }
                .padding(
                    .horizontal,
                    BrowserSpaceSwitcherLayout.compactStripHorizontalInset
                )

                BrowserSpaceSwitcherIconRow(
                    spaces: spaces,
                    selectedSpaceID: selectedSpaceID,
                    reorderState: reorderState,
                    selectSpace: selectSpace,
                    width: allocation.pickerViewportWidth,
                    menu: accessories.spaceMenu
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: BrowserSpaceSwitcherLayout.compactStripHeight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Spaces")
    }

    // MARK: - Actions - Accessories

    /// The sidebar toggle and the lists on the sidebar's own edge, the "+" on
    /// the other.
    @ViewBuilder
    private func accessory(at edge: HorizontalEdge) -> some View {
        if edge == sidebarEdge {
            HStack(spacing: BrowserSpaceSwitcherLayout.compactStripSpacing) {
                if let sidebarToggle = accessories.sidebarToggle {
                    toggleButton(sidebarToggle)
                }
                if let commonLists = accessories.commonLists {
                    commonListsButton(commonLists)
                }
            }
        } else if let newItems = accessories.newItems {
            newItemsMenu(newItems)
        }
    }

    private func utilityWidth(at edge: HorizontalEdge) -> CGFloat {
        let count =
            edge == sidebarEdge
            ? [accessories.sidebarToggle != nil, accessories.commonLists != nil].filter { $0 }.count
            : accessories.newItems == nil ? 0 : 1
        guard count > 0 else { return 0 }
        return CGFloat(count) * BrowserSpaceSwitcherLayout.utilityButtonSize
            + CGFloat(count - 1) * BrowserSpaceSwitcherLayout.compactStripSpacing
    }

    private func newItemsMenu(_ newItems: BrowserSpaceSwitcherNewItems) -> some View {
        Menu {
            Group {
                if let createSpace = newItems.createSpace {
                    Button("Create Space", systemImage: "square.on.square", action: createSpace)
                }
                if let createFolder = newItems.createFolder {
                    Button("Create Folder", systemImage: "folder", action: createFolder)
                }
                Divider()
                if let newSplit = newItems.newSplit {
                    Button("New Split", systemImage: "rectangle.split.2x1", action: newSplit)
                }
                Button("New Tab", systemImage: "plus", action: newItems.newTab)
            }
            .crestMenuActionLabelStyle()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: BrowserSpaceSwitcherLayout.utilityGlyphSize, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(
                    width: BrowserSpaceSwitcherLayout.utilityButtonSize,
                    height: BrowserSpaceSwitcherLayout.utilityButtonSize
                )
                .contentShape(.rect)
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.borderless)
        .fixedSize()
        .crestHoverLabel(Text("New"))
        .accessibilityLabel("New")
        .accessibilityIdentifier("browser-switcher-new")
    }

    private func toggleButton(
        _ sidebarToggle: BrowserSpaceSwitcherSidebarToggle
    ) -> some View {
        Button(
            sidebarToggle.action.title,
            systemImage: appearance.sidebarOnRight ? "sidebar.right" : "sidebar.left",
            action: sidebarToggle.toggle
        )
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .font(.system(size: BrowserSpaceSwitcherLayout.utilityGlyphSize, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(
            width: BrowserSpaceSwitcherLayout.utilityButtonSize,
            height: BrowserSpaceSwitcherLayout.utilityButtonSize
        )
        .accessibilityIdentifier("browser-sidebar-toggle")
        .help(Text("\(Text(sidebarToggle.action.title)) (⌘S)"))
    }

    private func commonListsButton(
        _ commonLists: BrowserSpaceSwitcherCommonLists
    ) -> some View {
        BrowserSpaceSwitcherCommonListsButton(
            isExpanded: commonLists.isExpanded,
            downloads: downloads.items,
            newDownloads: downloads.newItems,
            badgeColor: downloads.badgeColor,
            action: commonLists.toggle,
            recordFrame: commonLists.recordTriggerFrame
        )
    }
}
