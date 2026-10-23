import SwiftUI

/// A look as a gallery tile shows it: the Space's icon on a square of the
/// look's sidebar.
struct BrowserSpaceLookTile: View {
    let look: SpaceBranding
    let symbol: String
    let size: CGFloat

    var body: some View {
        BrowserCrestStudioMark(branding: look, symbol: symbol, size: size * 0.7)
            .frame(width: size, height: size)
            .background { BrowserSpaceBannerBackground(branding: look) }
            .clipShape(.rect(cornerRadius: CrestRadius.compact))
    }
}
