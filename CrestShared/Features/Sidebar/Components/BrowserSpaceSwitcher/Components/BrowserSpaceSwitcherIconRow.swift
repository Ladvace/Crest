import SwiftUI

/// The Spaces as a row of bare icons in the sidebar's text color, so each
/// reads against whatever Space's sidebar is behind it, the selected one at
/// full strength and the others dimmed. Once they don't all fit, every Space
/// but the selected one becomes a dot that shows its icon under the pointer,
/// and a row that still doesn't fit scrolls.
struct BrowserSpaceSwitcherIconRow: View {
    let spaces: [BrowserSpaceIdentity]
    let selectedSpaceID: UUID
    let reorderState: BrowserSidebarReorderState?
    let selectSpace: (UUID) -> Void
    let width: CGFloat
    var menu: BrowserSpaceSwitcherSpaceMenu? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var layout: BrowserSpaceSwitcherIconRowLayout {
        BrowserSpaceSwitcherLayout.iconRowLayout(width: width, spaceCount: spaces.count)
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row
            ScrollView(.horizontal) { row }
                .scrollIndicators(.never)
        }
        .frame(width: width)
        .animation(CrestMotion.scrollAlignment.unlessReducingMotion(reduceMotion), value: layout)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("space-switcher-picker")
        .accessibilitySortPriority(BrowserSpaceSwitcherLayout.pickerAccessibilityPriority)
    }

    private var row: some View {
        HStack(spacing: 0) {
            ForEach(spaces) { space in
                BrowserSpaceSwitcherIconButton(
                    space: space, isSelected: space.id == selectedSpaceID, layout: layout,
                    reorderState: reorderState, menu: menu
                ) {
                    selectSpace(space.id)
                }
            }
        }
    }
}

/// One Space in the row: its icon, or a dot while the row is collapsed and
/// the Space isn't the selected one. A lifted tab can be dropped on it.
private struct BrowserSpaceSwitcherIconButton: View {
    let space: BrowserSpaceIdentity
    let isSelected: Bool
    let layout: BrowserSpaceSwitcherIconRowLayout
    let reorderState: BrowserSidebarReorderState?
    let menu: BrowserSpaceSwitcherSpaceMenu?
    let select: () -> Void

    @State private var isHovering = false

    /// Whether the Space keeps a dot's slot: the row is collapsed and it isn't
    /// the selected Space.
    private var isCollapsed: Bool { layout.collapsesUnselected && !isSelected }

    var body: some View {
        Button(action: select) {
            Group {
                if isCollapsed && !isHovering {
                    Circle()
                        .fill(.primary)
                        .frame(width: BrowserSpaceSwitcherLayout.dotSize, height: BrowserSpaceSwitcherLayout.dotSize)
                } else {
                    // A dot under the pointer shows its icon in the dot's own
                    // slot, so the row never shifts beneath the pointer.
                    BrowserSpaceSwitcherGlyph(space: space, size: layout.iconSize)
                        .fixedSize()
                }
            }
            .frame(
                width: isCollapsed ? BrowserSpaceSwitcherLayout.dotSlotWidth : layout.iconSlotWidth,
                height: BrowserSpaceSwitcherLayout.utilityButtonSize
            )
            .opacity(isSelected ? 1 : isHovering ? 0.9 : 0.55)
            // The hover tint is a little larger than the icon, and may reach
            // over a dot's narrow slot, as Arc's does.
            .background {
                Color.clear
                    .frame(
                        width: BrowserSpaceSwitcherLayout.hoverSurfaceSize,
                        height: BrowserSpaceSwitcherLayout.hoverSurfaceSize
                    )
                    .crestInteractiveSurface(isSelected: false, isHovering: isHovering && !isSelected)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .modifier(BrowserSpaceSwitcherDropZone(space: space, reorderState: reorderState))
        .contextMenu {
            if let menu {
                Button("Edit Space…", systemImage: "pencil") { menu.edit(space.id) }
                if let create = menu.create {
                    Button("New Space…", systemImage: "plus", action: create)
                }
            }
        }
        .crestHoverLabel(Text(space.name))
        .accessibilityLabel(Text(space.name))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A Space's icon in the sidebar's text color, or its emoji in its own
/// colors, with the lock of a Space that asks for authentication.
private struct BrowserSpaceSwitcherGlyph: View {
    let space: BrowserSpaceIdentity
    let size: CGFloat

    var body: some View {
        Group {
            if let emoji = BrowserIconSymbol.emoji(from: space.symbol) {
                Text(emoji).font(.system(size: size * 0.8))
            } else {
                Image(systemName: space.symbol)
                    .font(.system(size: size * 0.72, weight: .semibold))
                    .foregroundStyle(.primary)
            }
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottomTrailing) {
            if space.requiresAuthentication {
                Image(systemName: "lock.fill")
                    .font(.system(size: max(5, size / 4), weight: .bold))
                    .foregroundStyle(.primary)
            }
        }
    }
}

/// Lets a lifted tab be dropped on a Space, where the shell tracks drags.
private struct BrowserSpaceSwitcherDropZone: ViewModifier {
    let space: BrowserSpaceIdentity
    let reorderState: BrowserSidebarReorderState?

    func body(content: Content) -> some View {
        if let reorderState {
            content
                .browserSidebarReorderZone(.space(space.assignment), state: reorderState)
                .accessibilityHint("Select this Space, or drop a tab to move it here")
        } else {
            content
        }
    }
}
