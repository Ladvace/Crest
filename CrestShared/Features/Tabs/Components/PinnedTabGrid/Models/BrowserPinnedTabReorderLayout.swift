import CoreGraphics

/// The temporary pinned slots, shared by rendering and drop hit testing.
/// A lifted tile stays alive in the view tree but occupies no slot of its own.
struct BrowserPinnedTabReorderLayout: Equatable {
    // MARK: - Static Variables

    static let cellHeight: CGFloat = 38
    static let spacing: CGFloat = 6

    /// The most tiles a row holds, and the width below which the automatic
    /// layout starts a new row.
    static let maximumColumns = 6
    static let automaticTileWidth: CGFloat = 44

    // MARK: - Types

    enum Slot: Hashable {
        case tab(BrowserSidebarReorderItemID)
        case gap
    }

    // MARK: - Variables

    let ids: [BrowserSidebarReorderItemID]
    var liftedID: BrowserSidebarReorderItemID?
    var liftedIDs: Set<BrowserSidebarReorderItemID> = []
    var insertionIndex: Int?
    var availableWidth: CGFloat = BrowserChromeLayout.sidebarIdealWidth
    var preferredColumns = 0
    var tabScale = 1.0
    var tileHeight: CGFloat = Self.cellHeight
    var tileSpacing: CGFloat = Self.spacing
    var minimumTileWidth: CGFloat = BrowserSidebarDensity(1).pinMinimumWidth(touch: false)

    var slots: [Slot] {
        var result = ids.filter { $0 != liftedID && !liftedIDs.contains($0) }.map(Slot.tab)
        if let insertionIndex {
            result.insert(.gap, at: min(max(0, insertionIndex), result.count))
        }
        return result
    }

    /// How many tiles a row holds. The automatic layout fits as many compact
    /// tiles as the sidebar allows, and fewer pins share the row between
    /// them, so the grid always spans the sidebar's width and its tiles grow
    /// and shrink with it. A chosen count fills rows to it.
    var columns: Int {
        columns(holding: slots.count)
    }

    var height: CGFloat {
        let slotCount = slots.count
        guard slotCount > 0 else { return 0 }
        let columns = columns(holding: slotCount)
        let rows = (slotCount + columns - 1) / columns
        return CGFloat(rows) * tileHeight + CGFloat(rows - 1) * tileSpacing
    }

    /// How many tiles a row holds when the grid holds `slotCount`.
    private func columns(holding slotCount: Int) -> Int {
        let width =
            availableWidth.isFinite ? min(max(0, availableWidth), 10_000) : BrowserChromeLayout.sidebarIdealWidth
        guard preferredColumns == 0 else {
            let fitting = max(1, Int((width + tileSpacing) / (minimumTileWidth + tileSpacing)))
            return min(max(slotCount, 1), min(max(preferredColumns, 1), Self.maximumColumns), fitting)
        }
        let tileWidth = max(minimumTileWidth, Self.automaticTileWidth * BrowserSidebarDensity(tabScale).scale)
        let fitting = max(1, Int((width + tileSpacing) / (tileWidth + tileSpacing)))
        return min(Self.maximumColumns, fitting, max(slotCount, 1))
    }

    // MARK: - Actions - Layout

    func frame(for slot: Slot, in bounds: CGRect) -> CGRect? {
        let slots = slots
        guard let index = slots.firstIndex(of: slot) else { return nil }
        return frame(at: index, columns: columns(holding: slots.count), in: bounds)
    }

    /// Every slot's frame in `bounds`, worked out in one pass: a layout that
    /// asked `frame(for:in:)` tile by tile rebuilt the slots for each one.
    func frames(in bounds: CGRect) -> [Slot: CGRect] {
        let slots = slots
        let columns = columns(holding: slots.count)
        var frames: [Slot: CGRect] = [:]
        for (index, slot) in slots.enumerated() {
            frames[slot] = frame(at: index, columns: columns, in: bounds)
        }
        return frames
    }

    private func frame(at index: Int, columns: Int, in bounds: CGRect) -> CGRect {
        let width = max(0, (bounds.width - CGFloat(columns - 1) * tileSpacing) / CGFloat(columns))
        return CGRect(
            x: bounds.minX + CGFloat(index % columns) * (width + tileSpacing),
            y: bounds.minY + CGFloat(index / columns) * (tileHeight + tileSpacing),
            width: width, height: tileHeight)
    }

    // MARK: - Actions - Preferences

    @MainActor
    func applyingPreferences(width: CGFloat, touch: Bool) -> Self {
        var value = self
        value.availableWidth = width.isFinite ? max(0, width) : BrowserChromeLayout.sidebarIdealWidth
        value.preferredColumns = Int(
            min(
                max(
                    BrowserSidebarDensityPreference.number(BrowserSidebarDensityPreference.pinColumnsKey, default: 0), 0
                ), 6))
        let scale = BrowserSidebarDensityPreference.number(BrowserSidebarDensityPreference.scaleKey, default: 1)
        value.tabScale = scale
        value.tileHeight = BrowserSidebarDensity(scale).pinHeight(touch: touch)
        value.tileSpacing = BrowserSidebarDensity(scale).pinSpacing
        value.minimumTileWidth = BrowserSidebarDensity(scale).pinMinimumWidth(touch: touch)
        return value
    }
}
