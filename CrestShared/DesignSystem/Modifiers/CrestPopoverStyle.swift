import SwiftUI

/// Every popover Crest opens from its chrome wears one surface, drawn the way
/// the system's own menus are: the device's surface material in the popover's
/// own appearance, which follows the device rather than the Space it opened
/// from. A popover opened from a Space's sidebar would otherwise take the
/// Space's ink, light or dark, against a material that follows the device, and
/// its labels would wash out. A color-scheme override alone does not replace an
/// inherited foreground style, so the labels are set too.
struct CrestPopoverStyle: ViewModifier {
    // MARK: - Static Variables

    /// How much of Crest's surface covers the material.
    private static let surfaceOpacity = 0.9

    // MARK: - Variables

    @Environment(\.crestSurfaceMaterial) private var surfaceMaterial
    /// The appearance the popover's window reported; nil until it does.
    @State private var reportedColorScheme: ColorScheme?

    private var colorScheme: ColorScheme {
        reportedColorScheme ?? CrestPopoverAppearanceReader.expected
    }

    // MARK: - Actions - Body

    func body(content: Content) -> some View {
        content
            .font(.body)
            .foregroundStyle(Color.primary)
            // The device's own accent, as the system's controls wear it.
            .tint(Color.accentColor)
            .environment(\.colorScheme, colorScheme)
            .background {
                CrestPopoverAppearanceReader(colorScheme: $reportedColorScheme)
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            }
            .presentationBackground {
                // The material alone lets a bright Space's sidebar glow
                // through, so a neutral surface lies on it nearly opaque.
                ZStack {
                    Rectangle().fill(surfaceMaterial.material)
                    CrestBrandTheme.popoverSurface(colorScheme).opacity(Self.surfaceOpacity)
                }
                .environment(\.colorScheme, colorScheme)
            }
    }
}

#if DEBUG
    #Preview("A popover opened from a light Space") {
        VStack(alignment: .leading, spacing: CrestSpacing.medium) {
            Text("Bookmarks").font(.headline)
            Text(verbatim: "example.com").font(.caption).foregroundStyle(.secondary)
            Divider()
            Label("Reading", systemImage: "folder")
        }
        .padding(CrestSpacing.medium)
        .frame(width: 280)
        .modifier(CrestPopoverStyle())
        .background { CrestSurfaceLayer(shape: Rectangle()) }
        .padding()
        .background(.yellow.gradient)
        .foregroundStyle(Color.black)
        .environment(\.colorScheme, .light)
    }
#endif
