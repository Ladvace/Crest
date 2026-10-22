import SwiftUI

extension SpaceBranding {
    // MARK: - Icon color

    /// Paints the Space's icon in `color` of its own, apart from the sidebar.
    mutating func setForgeIconColor(_ color: BrandColor) {
        hasCustomAppearance = true
        symbolColor = color
    }

    // MARK: - Sidebar colors

    func forgeColor(of role: BrowserSpaceBrandColorRole) -> BrandColor {
        colors.indices.contains(role.slot) ? colors[role.slot] : (colors.last ?? .indigo)
    }

    /// Paints one sidebar color, giving the Space's palette every role up to
    /// this one.
    mutating func setForgeColor(_ color: BrandColor, of role: BrowserSpaceBrandColorRole) {
        hasCustomAppearance = true
        while colors.count <= role.slot { colors.append(colors.last ?? color) }
        colors[role.slot] = color
    }
}

/// The tinctures the templates are made of, a template to a column, darkest
/// first.
struct BrowserCrestForgePalette: View {
    let title: LocalizedStringResource
    var caption: LocalizedStringResource? = nil
    let color: BrandColor
    let select: (BrandColor) -> Void

    private let houses = SpaceHouse.all

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                if let caption {
                    Text(caption).font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack(alignment: .top, spacing: 6) {
                ForEach(houses, id: \.self) { house in
                    VStack(spacing: 6) {
                        ForEach(house.tinctures, id: \.self) { tincture($0) }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(Text(house.title))
                }
            }
            ColorPicker(
                "Custom",
                selection: Binding(get: { color.color }, set: { select(BrandColor(color: $0)) }),
                supportsOpacity: false
            )
        }
        .padding(14)
        .fixedSize()
    }

    private func tincture(_ tincture: BrandColor) -> some View {
        let isSelected = tincture.matches(color)
        return Button {
            select(tincture)
        } label: {
            Circle()
                .fill(tincture.color)
                .frame(width: 24, height: 24)
                .overlay { Circle().strokeBorder(.primary.opacity(0.15)) }
                .padding(3)
                .overlay { Circle().strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2) }
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .help(Text(tincture.title))
        .accessibilityLabel(Text(tincture.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
