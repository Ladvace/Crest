import Foundation

/// A house as the starting point of a Space's look.
extension SpaceHouse {
    /// The house a look started from, by the name it recorded. Earlier builds
    /// recorded the house's English title, which differs only in case.
    static func startingPoint(of branding: SpaceBranding) -> SpaceHouse? {
        guard let recorded = branding.crest.startingPresetID else { return nil }
        return all.first { $0.name.caseInsensitiveCompare(recorded) == .orderedSame }
    }

    /// `branding` starting over from the house's look, keeping the Space's
    /// own strengths, folder and text choices.
    func applying(to branding: SpaceBranding) -> SpaceBranding {
        var updated = branding
        updated.colors = look.colors
        updated.themeMode = look.themeMode
        updated.bannerPattern = look.bannerPattern
        updated.gradientAngle = look.gradientAngle
        updated.symbolColor = look.symbolColor
        updated.crest = look.crest
        updated.crest.startingPresetID = name
        updated.hasCustomAppearance = false
        return updated.normalized()
    }

    /// Whether `branding` still wears the house's look unchanged.
    func isWorn(by branding: SpaceBranding) -> Bool {
        branding.hasCustomAppearance != true && branding.colors == look.colors
            && branding.themeMode == look.themeMode
            && (look.themeMode == .gradient || branding.bannerPattern == look.bannerPattern)
            && branding.symbolColor == look.symbolColor
    }

    /// The colors the house is made of, darkest first.
    var tinctures: [BrandColor] {
        var seen: [BrandColor] = []
        for color in Array(look.colors) + [look.resolvedSymbolColor]
        where !seen.contains(where: { $0.matches(color) }) {
            seen.append(color)
        }
        return seen.sorted { $0.luminance < $1.luminance }
    }
}
