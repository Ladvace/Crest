import SwiftUI

/// What a first run changes on a banner Space: the template it starts from,
/// its icon, its colors and its sidebar.
struct BrowserOnboardingHeraldicSheet: View {
    @Binding var branding: SpaceBranding
    @Binding var symbol: String
    @State private var choosesEmoji = false

    private var context: BrowserCrestStudioContext {
        BrowserCrestStudioContext(
            branding: $branding, defaults: SpaceHouse.startingPoint(of: branding)?.look ?? branding, compact: false,
            previewBranding: nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            startFrom
            icon
            colors
            sidebar
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Sections

    private var startFrom: some View {
        BrowserOnboardingMakeSection("Start from") {
            BrowserOnboardingMakeStrip {
                ForEach(SpaceHouse.all, id: \.self) { house in
                    BrowserOnboardingMakeTile(title: house.title, isSelected: house.isWorn(by: branding)) {
                        branding = house.applying(to: branding)
                    } artwork: {
                        houseArtwork(house.applying(to: branding))
                    }
                }
            }
        }
    }

    private var icon: some View {
        BrowserOnboardingMakeSection("Icon") {
            iconChoices
        }
    }

    private var iconChoices: some View {
        HStack(spacing: 12) {
            BrowserSystemSymbolPicker(
                selection: Binding(
                    get: { BrowserIconSymbol.emoji(from: symbol) == nil ? symbol : "" }, set: { symbol = $0 }))
            BrowserArtworkPickerButton(
                title: "Emoji",
                detail: BrowserIconSymbol.emoji(from: symbol) == nil ? Text("Choose an emoji") : Text("Change emoji")
            ) {
                choosesEmoji = true
            } artwork: {
                if let emoji = BrowserIconSymbol.emoji(from: symbol) {
                    Text(emoji)
                } else {
                    Image(systemName: "face.smiling")
                }
            }
            .accessibilityLabel("Choose Emoji")
            .browserIconCustomizationPopover(
                .init(
                    isPresented: $choosesEmoji, title: "Space Icon",
                    currentEmoji: BrowserIconSymbol.emoji(from: symbol),
                    setEmoji: { symbol = BrowserIconSymbol.symbol(forEmoji: $0) }))
        }
        .frame(maxWidth: 520)
    }

    private var colors: some View {
        BrowserOnboardingMakeSection("Colors") {
            HStack(spacing: 0) {
                BrowserOnboardingMakeSwatch(title: "Icon", color: branding.resolvedSymbolColor) { color in
                    branding.setForgeIconColor(color)
                    branding = branding.normalized()
                }
                Divider()
                    .frame(height: BrowserOnboardingMakeMetrics.swatchSize)
                    .padding(.horizontal, 10)
                BrowserOnboardingSidebarSwatches(branding: $branding)
            }
        }
    }

    private var sidebar: some View {
        BrowserOnboardingMakeSection("Sidebar") {
            BrowserOnboardingMakeStrip {
                ForEach(SpaceBannerPattern.all, id: \.self) { pattern in
                    BrowserOnboardingMakeTile(
                        title: pattern.title,
                        isSelected: branding.themeMode == .banner && branding.bannerPattern == pattern
                    ) {
                        context.branding.editorUpdate {
                            $0.themeMode = .banner
                            $0.bannerPattern = pattern
                            $0.hasCustomAppearance = true
                        }
                    } artwork: {
                        field(
                            context.preview {
                                $0.themeMode = .banner
                                $0.bannerPattern = pattern
                            })
                    }
                }
                BrowserOnboardingMakeTile(title: "Gradient", isSelected: branding.themeMode == .gradient) {
                    context.branding.editorUpdate {
                        $0.themeMode = .gradient
                        $0.hasCustomAppearance = true
                    }
                } artwork: {
                    field(context.preview { $0.themeMode = .gradient })
                }
            }
        }
    }

    // MARK: - Artwork

    /// A template's tile: its sidebar under the Space's icon in its colors.
    private func houseArtwork(_ look: SpaceBranding) -> some View {
        let size = BrowserOnboardingMakeMetrics.tileArtworkSize
        return BrowserCrestStudioMark(branding: look, symbol: symbol, size: size * 0.7)
            .frame(width: size, height: size)
            .background { field(look) }
    }

    private func field(_ look: SpaceBranding) -> some View {
        BrowserSpaceBannerBackground(branding: look)
            .clipShape(.rect(cornerRadius: 7, style: .continuous))
    }
}

/// The three colors a sidebar wears, each opening the tinctures.
struct BrowserOnboardingSidebarSwatches: View {
    @Binding var branding: SpaceBranding

    var body: some View {
        ForEach(BrowserSpaceBrandColorRole.all) { role in
            BrowserOnboardingMakeSwatch(title: role.title, caption: role.caption, color: branding.forgeColor(of: role))
            {
                color in
                branding.setForgeColor(color, of: role)
                branding = branding.normalized()
            }
        }
    }
}
