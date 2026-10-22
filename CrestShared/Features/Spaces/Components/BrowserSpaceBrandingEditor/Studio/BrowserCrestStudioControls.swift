import SwiftUI

/// Bindings normalize at the editing boundary, shared by setup drafts and live Spaces.
@MainActor
struct BrowserCrestStudioContext {
    let branding: Binding<SpaceBranding>
    let defaults: SpaceBranding
    var compact: Bool
    var previewBranding: SpaceBranding?
    var value: SpaceBranding { branding.wrappedValue }

    func preview(_ mutation: (inout SpaceBranding) -> Void) -> SpaceBranding {
        var candidate = previewBranding ?? value
        mutation(&candidate)
        return candidate.normalized()
    }

    func setting<Value: Equatable>(_ path: WritableKeyPath<SpaceBranding, Value>) -> CrestSettingValue<Value> {
        CrestSettingValue(
            Binding(
                get: { value[keyPath: path] },
                set: { next in
                    branding.editorUpdate {
                        $0[keyPath: path] = next
                        $0.hasCustomAppearance = true
                    }
                }), default: defaults[keyPath: path])
    }
}

struct BrowserCrestStudioSlider: View {
    @Environment(\.crestStudioEditingChanged) private var editingChanged
    let title: LocalizedStringKey
    let value: CrestSettingValue<Double>
    var range: ClosedRange<Double> = 0...1
    var readout: CrestSettingSliderReadout = .percent

    var body: some View {
        CrestSettingSlider(
            title, value: value, range: range, readout: readout,
            onEditingChanged: editingChanged.callAsFunction
        )
    }
}

/// Small cards keep one scroll owner in Settings and in onboarding.
struct BrowserCrestStudioGroup<Content: View>: View {
    let title: LocalizedStringResource
    let systemImage: String
    var preview: SpaceBranding? = nil
    var symbol: String = "sparkles"
    @ViewBuilder var content: Content

    init(
        title: LocalizedStringResource, systemImage: String, preview: SpaceBranding? = nil, symbol: String = "sparkles",
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.preview = preview
        self.symbol = symbol
        self.content = content()
    }

    /// The group for one step of making a look, named and marked as the step is.
    init(
        step: BrowserCrestStudioStep, preview: SpaceBranding? = nil, symbol: String = "sparkles",
        @ViewBuilder content: () -> Content
    ) {
        self.init(title: step.title, systemImage: step.symbol, preview: preview, symbol: symbol, content: content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if let preview {
                    BrowserCrestStudioMark(branding: preview, symbol: symbol, size: 56)
                        .frame(width: 72, height: 64)
                        .background { BrowserSpaceBannerBackground(branding: preview) }
                        .clipShape(.rect(cornerRadius: 12))
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            VStack(alignment: .leading, spacing: 16) { content }
                .padding(20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.primary.opacity(0.035), in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.primary.opacity(0.055))
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(title))
    }
}

extension EnvironmentValues {
    @Entry var crestStudioEditingChanged = BrowserCrestStudioEditingAction()
}

struct BrowserCrestStudioEditingAction {
    var update: (Bool) -> Void = { _ in }

    func callAsFunction(_ editing: Bool) { update(editing) }
}

struct BrowserCrestStudioChoice<Artwork: View>: View {
    let title: LocalizedStringResource
    let selected: Bool
    /// The color that marks the chosen tile.
    var tint: Color = CrestBrandTheme.accent
    let select: () -> Void
    @ViewBuilder var artwork: Artwork

    var body: some View {
        Button(action: select) {
            VStack(spacing: 4) {
                artwork.frame(width: 64, height: 58)
                Text(title).font(.caption).lineLimit(2).multilineTextAlignment(.center)
                    .frame(height: 30, alignment: .top)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                selected ? tint.opacity(0.12) : .primary.opacity(0.035), in: .rect(cornerRadius: 12)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12).strokeBorder(
                    selected ? tint : .clear, lineWidth: 2)
            }
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
