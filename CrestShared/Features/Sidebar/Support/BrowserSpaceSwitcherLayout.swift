import CoreGraphics
import Foundation

/// Shared Space picker sizing and the lane reserved between sidebar utilities.
enum BrowserSpaceSwitcherLayout {
    static let utilityButtonSize: CGFloat = 24

    /// The glyph the strip's buttons draw, in the sidebar's quieter text color.
    static let utilityGlyphSize: CGFloat = 10
    static let segmentWidth = CrestSpaceIconPickerMetrics.segmentWidth
    static let overflowButtonWidth = CrestSpaceIconPickerMetrics.overflowButtonWidth

    /// The band the compact strip occupies, which is what holds the picker
    /// clear of the sidebar's bottom edge and the utilities either side of it.
    static let compactStripHeight: CGFloat = 50

    /// The inset that keeps the compact strip in the same column as the rows
    /// above it.
    static let compactStripHorizontalInset: CGFloat = 12

    /// The gap between the strip's utilities and the picker between them.
    static let compactStripSpacing: CGFloat = 2

    /// VoiceOver follows the same leading-to-trailing order users see even
    /// though the centred picker is composed in a `ZStack`.
    static let leadingUtilityAccessibilityPriority: Double = 3
    static let pickerAccessibilityPriority: Double = 2
    static let trailingUtilityAccessibilityPriority: Double = 1

    /// The inset that lines the scrolling track up with the sidebar's rows,
    /// and the gap between it and the chrome above.
    static let scrollingTrackHorizontalInset: CGFloat = 12
    static let scrollingTrackTopInset: CGFloat = 6

    /// Resolves the compact picker's centred viewport inside the utility
    /// buttons that flank it.
    ///
    /// The larger utility side is reserved on both sides. That keeps the
    /// picker centred when one accessory is absent or wider, while the actual
    /// leading and trailing widths still determine the no-overlap edges.
    static func compactStripAllocation(
        availableWidth: CGFloat,
        spaceCount: Int,
        leadingUtilityWidth: CGFloat,
        trailingUtilityWidth: CGFloat
    ) -> BrowserSpaceSwitcherCompactAllocation {
        let width = max(0, availableWidth)
        let leadingWidth = max(0, leadingUtilityWidth)
        let trailingWidth = max(0, trailingUtilityWidth)
        let leadingReservation = utilityReservation(for: leadingWidth)
        let trailingReservation = utilityReservation(for: trailingWidth)
        let balancedSideReservation = max(
            leadingReservation,
            trailingReservation
        )
        let contentWidth = max(0, width - 2 * compactStripHorizontalInset)
        let pickerViewportWidth = max(
            0,
            contentWidth - 2 * balancedSideReservation
        )

        return BrowserSpaceSwitcherCompactAllocation(
            pickerViewportWidth: pickerViewportWidth,
            pickerContentWidth: compactPickerContentWidth(
                spaceCount: spaceCount
            )
        )
    }

    /// The size a Space's icon is drawn at, and the room around each icon.
    static let iconSizes: [CGFloat] = [15]
    static let iconSlotPadding: CGFloat = 14

    /// The dot an unselected Space shrinks to once even the smallest icons
    /// don't fit, and the room around it.
    static let dotSize: CGFloat = 4
    /// The tint behind a Space under the pointer.
    static let hoverSurfaceSize: CGFloat = 30
    static let dotSlotWidth: CGFloat = 12

    /// How the strip draws `spaceCount` Spaces in `width`: every Space's icon
    /// at full size when they all fit, or else, as Arc does, the selected
    /// Space's icon and a dot for each other, which shows its icon while the
    /// pointer is over it. A row that still doesn't fit scrolls.
    static func iconRowLayout(width: CGFloat, spaceCount: Int) -> BrowserSpaceSwitcherIconRowLayout {
        let count = CGFloat(max(1, spaceCount))
        let size = iconSizes.first ?? 15
        return BrowserSpaceSwitcherIconRowLayout(
            iconSize: size, collapsesUnselected: count * (size + iconSlotPadding) > width)
    }

    /// The active Space is the semantic scroll target. Falling back to the
    /// first surviving identity keeps a transient removal repair navigable
    /// without introducing a second selection model in the view.
    static func compactScrollTarget(
        spaceIDs: [UUID],
        selectedSpaceID: UUID
    ) -> UUID? {
        guard !spaceIDs.isEmpty else { return nil }
        return spaceIDs.contains(selectedSpaceID)
            ? selectedSpaceID
            : spaceIDs.first
    }

    private static func utilityReservation(for width: CGFloat) -> CGFloat {
        width > 0 ? width + compactStripSpacing : 0
    }

    private static func compactPickerContentWidth(spaceCount: Int) -> CGFloat {
        let count = max(0, spaceCount)
        guard count > 0 else { return 0 }
        return 2 * CrestSpaceIconPickerMetrics.trackPadding
            + CGFloat(count) * segmentWidth
            + CGFloat(count - 1) * CrestLayout.hairline
    }
}

struct BrowserSpaceSwitcherCompactAllocation: Equatable, Sendable {
    let pickerViewportWidth: CGFloat
    let pickerContentWidth: CGFloat
    var overflowButtonWidth: CGFloat = BrowserSpaceSwitcherLayout.overflowButtonWidth

    var usesOverflow: Bool {
        pickerContentWidth > pickerViewportWidth
    }

    var scrollViewportWidth: CGFloat {
        max(0, pickerViewportWidth - (usesOverflow ? 2 * overflowButtonWidth : 0))
    }

}

/// How the strip draws its Spaces: each as an icon of `iconSize`, or, when
/// `collapsesUnselected`, only the selected one as an icon and every other as
/// a dot.
struct BrowserSpaceSwitcherIconRowLayout: Equatable, Sendable {
    let iconSize: CGFloat
    let collapsesUnselected: Bool

    var iconSlotWidth: CGFloat { iconSize + BrowserSpaceSwitcherLayout.iconSlotPadding }
}
