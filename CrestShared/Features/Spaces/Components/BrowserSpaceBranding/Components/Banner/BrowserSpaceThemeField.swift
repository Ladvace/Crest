import SwiftUI

/// A Space's sidebar field: one solid color, or a gradient of its colors. A
/// patterned banner from an older Crest, which this build no longer draws,
/// runs as a gradient down the sidebar, as the core reads it.
struct BrowserSpaceThemeField: View {
    let themeMode: SpaceThemeMode
    let bannerPattern: SpaceBannerPattern
    let gradientAngle: Double
    let colors: [Color]

    @ViewBuilder
    var body: some View {
        switch themeMode.kind {
        case .banner where bannerPattern == .solid:
            colors[0]
        case .banner:
            BrowserSpaceGradientField(colors: colors, angle: BrowserSpaceThemeField.downwardAngle)
        case .gradient:
            BrowserSpaceGradientField(colors: colors, angle: gradientAngle)
        }
    }

    /// The angle a gradient runs at straight down the sidebar.
    private static let downwardAngle = 90.0
}
