import SwiftUI

struct BrowserCrestStudioBackground: View {
    let context: BrowserCrestStudioContext
    let symbol: String
    var body: some View {
        BrowserCrestStudioGroup(title: "Space background", systemImage: "rectangle.inset.filled") {
            if context.compact {
                BrowserCrestStudioPreview(branding: context.value, symbol: symbol, compact: true)
            }
            HStack(spacing: 16) {
                ForEach(BrowserSpaceBrandColorRole.all) { role in
                    BrowserSpacePaletteSlot(
                        role: role, color: context.branding.editorColor(for: role),
                        canAdd: role.slot == context.value.colors.count,
                        canRemove: role.slot == context.value.colors.count - 1 && context.value.colors.count > 1,
                        compact: true, addColor: { context.branding.editorAddColor(for: role) },
                        removeColor: { context.branding.editorRemoveColor(for: role) })
                }
            }
            BrowserCrestStudioFillPicker(context: context)
            if context.value.themeMode == .gradient {
                let angle = context.setting(\.gradientAngle)
                CrestSettingRow("Gradient angle", setting: angle.resettable("Gradient angle")) {
                    HStack(spacing: 16) {
                        Text("\(Int(angle.wrappedValue.rounded()))°")
                            .monospacedDigit().foregroundStyle(.secondary)
                        BrowserSpaceGradientAngleDial(angle: angle.binding, color: context.value.secondaryColor.color)
                            .frame(width: 72, height: 72)
                    }
                }
            }
            slider("Color intensity", \.bannerStrength)
            slider("Readability fade", \.readabilityFade)
            slider("Folder color intensity", \.folderColorIntensity)
            let texture = context.setting(\.showsTexture)
            CrestSettingRow("Texture", setting: texture.resettable("Texture")) {
                Toggle("Texture", isOn: texture.binding).labelsHidden()
            }
            let text = context.setting(\.textColorMode)
            CrestSettingRow("Text color", setting: text.resettable("Text color")) {
                Picker("Text color", selection: text.binding) {
                    Text("Automatic").tag(SpaceTextColorMode.automatic)
                    Text("Light").tag(SpaceTextColorMode.light)
                    Text("Dark").tag(SpaceTextColorMode.dark)
                }.labelsHidden()
            }
        }
    }

    private func slider(
        _ title: LocalizedStringKey, _ path: WritableKeyPath<SpaceBranding, Double>,
        range: ClosedRange<Double> = 0...1, readout: CrestSettingSliderReadout = .percent
    ) -> some View {
        BrowserCrestStudioSlider(title: title, value: context.setting(path), range: range, readout: readout)
    }
}

#if DEBUG
    #Preview("Interactive background controls") {
        @Previewable @State var branding = BrowserSpaceBrandingPreviewFixture.solidBranding
        Form {
            BrowserCrestStudioBackground(
                context: BrowserCrestStudioContext(
                    branding: $branding, defaults: BrowserSpaceBrandingPreviewFixture.solidBranding, compact: false),
                symbol: "crown.fill")
        }.crestSettingsForm().frame(width: 480, height: 650)
    }
#endif
