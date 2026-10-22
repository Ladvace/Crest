import SwiftUI

/// What a look shows of itself before any Space wears it: a template's look
/// in the look's own sidebar mode, as the core gives it to the Spaces setup
/// makes.
extension SetupLook {
    // MARK: - Static Variables

    /// The template every look's preview starts from.
    private static let previewHouse = SpaceHouse.winter

    /// The angle a modern gradient runs at: straight down the sidebar.
    private static let modernGradientAngle = 90.0

    // MARK: - Variables

    /// The look on the template every preview starts from.
    var previewBranding: SpaceBranding { applying(to: Self.previewHouse.look) }

    /// The symbol a previewed Space wears.
    var previewSymbol: String { "house.fill" }

    // MARK: - Actions - Looks

    /// `branding` in this look: its sidebar mode, keeping its colors.
    func applying(to branding: SpaceBranding) -> SpaceBranding {
        var look = branding
        switch kind {
        case .heraldic:
            look.themeMode = .banner
        case .modern:
            look.themeMode = .gradient
            look.gradientAngle = Self.modernGradientAngle
        }
        return look.normalized()
    }
}
