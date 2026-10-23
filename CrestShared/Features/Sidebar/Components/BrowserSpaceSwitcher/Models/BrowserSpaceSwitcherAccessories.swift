import CoreGraphics
import Foundation

/// The controls a shell asks the Space switcher to carry alongside its
/// Spaces.
///
/// Only an arrangement with room either side of its picker can carry any, so
/// each one is optional and the scrolling track ignores both. They are inputs
/// rather than a fixed pair because the same strip should be able to lose the
/// sidebar toggle — a docked window has nothing to toggle — without the
/// switcher learning about docking.
struct BrowserSpaceSwitcherAccessories {
    var sidebarToggle: BrowserSpaceSwitcherSidebarToggle?
    var commonLists: BrowserSpaceSwitcherCommonLists?
    var spaceMenu: BrowserSpaceSwitcherSpaceMenu?
    var newItems: BrowserSpaceSwitcherNewItems?
}

/// The switcher's "+" on the page side: a new tab, a new split, a folder or
/// a Space. A route is absent where the shell can't take it right now.
struct BrowserSpaceSwitcherNewItems {
    let newTab: () -> Void
    let newSplit: (() -> Void)?
    let createFolder: (() -> Void)?
    let createSpace: (() -> Void)?
}

/// What a Space's icon offers when right-clicked: editing that Space's name,
/// icon and look, and adding a Space where the shell can.
struct BrowserSpaceSwitcherSpaceMenu {
    let edit: (UUID) -> Void
    let create: (() -> Void)?
}

/// The switcher's accessory at the window's edge: show or hide the sidebar
/// the switcher is standing in.
struct BrowserSpaceSwitcherSidebarToggle {
    let action: BrowserSidebarToggleAction
    let toggle: () -> Void
}

/// The switcher's accessory beside the sidebar toggle: the archive, history,
/// and downloads lists, and the badge that says how many finished downloads have
/// not been looked at yet.
struct BrowserSpaceSwitcherCommonLists {
    let isExpanded: Bool
    let toggle: () -> Void

    /// Reports where the trigger ended up, so the lists can fan out from it.
    let recordTriggerFrame: (CGRect) -> Void
}
