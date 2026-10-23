import Foundation

/// The colors a Space's look draws with, by the part each plays, and the
/// core's branding rules applied to a look being edited.
extension SpaceBranding {
    // MARK: - Static Variables

    /// The least contrast an icon keeps against its sidebar, as for any
    /// meaningful graphic.
    private static let minimumSymbolContrast = 3.0

    // MARK: - Variables

    var backgroundColor: BrandColor {
        color(for: .background) ?? .indigo
    }

    var primaryColor: BrandColor {
        color(for: .accent) ?? backgroundColor
    }

    var secondaryColor: BrandColor {
        color(for: .pattern) ?? primaryColor
    }

    /// The icon's own color, or the Space's primary color, which it follows
    /// as the palette changes, when it has none. A color that would barely
    /// stand out from the sidebar gives way to the sidebar's text color.
    var resolvedSymbolColor: BrandColor {
        let color = symbolColor ?? primaryColor
        // The tone the Space's own colors give its sidebar, which a Neutral
        // look's appearance can't change: its colors are already grays.
        let tone = (colors.isEmpty ? [.indigo] : colors).foregroundTone(
            strength: bannerStrength, readabilityFade: readabilityFade)
        let contrast = (colors.isEmpty ? [.indigo] : colors).minimumContrast(
            of: color, under: tone, strength: bannerStrength, readabilityFade: readabilityFade)
        guard contrast < Self.minimumSymbolContrast else { return color }
        return tone == .light
            ? BrandColor(red: 1, green: 1, blue: 1, alpha: 1) : BrandColor(red: 0, green: 0, blue: 0, alpha: 1)
    }

    // MARK: - Actions - Text

    /// The tone that reads best over the banner, unless the text color mode
    /// names one or follows the device, whose appearance reads in `system`.
    func foregroundTone(system: BrowserSpaceForegroundTone) -> BrowserSpaceForegroundTone {
        if let override = textColorMode.foregroundTone(system: system) { return override }
        return (colors.isEmpty ? [.indigo] : colors).foregroundTone(
            strength: bannerStrength, readabilityFade: readabilityFade)
    }

    // MARK: - Actions - Colors

    func color(for role: BrowserSpaceBrandColorRole) -> BrandColor? {
        colors.indices.contains(role.slot) ? colors[role.slot] : nil
    }

    // MARK: - Actions - Normalizing

    /// This look with the core's branding rules applied, announcing the
    /// readability and rendering vocabulary it needs, as a Space keeps it. A
    /// core that cannot answer keeps the look as it is.
    func normalized() -> SpaceBranding {
        (try? CrestCore.answer(NormalizeBranding(branding: self)))?.branding ?? self
    }
}
