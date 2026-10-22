import SwiftUI

/// Whether a Space's sidebar runs its colors as a gradient or stands solid in
/// its background color.
struct BrowserCrestStudioFillPicker: View {
    let context: BrowserCrestStudioContext

    var body: some View {
        let mode = context.setting(\.themeMode)
        CrestSettingRow("Fill", setting: mode.resettable("Fill")) {
            Picker("Fill", selection: isGradient) {
                Text("Gradient").tag(true)
                Text("Solid").tag(false)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            #if os(macOS)
                .fixedSize()
            #endif
            .accessibilityIdentifier("space-forge-fill")
        }
    }

    private var isGradient: Binding<Bool> {
        Binding(
            get: { context.value.themeMode == .gradient },
            set: { gradient in
                context.branding.editorUpdate {
                    $0.themeMode = gradient ? .gradient : .banner
                    $0.bannerPattern = .solid
                    $0.hasCustomAppearance = true
                }
            })
    }
}
