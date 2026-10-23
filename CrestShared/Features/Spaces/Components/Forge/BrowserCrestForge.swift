import SwiftUI

/// A Space's Crest Studio: the Space's icon on its own sidebar field, and one
/// step of its look at a time, beside the window's live sidebar.
struct BrowserCrestForge: View {
    @Binding var branding: SpaceBranding
    @Binding var symbol: String
    @Binding var step: BrowserCrestStudioStep
    /// The Space's name, for a page that doesn't already let a person edit it.
    var name: Binding<String>? = nil
    /// Whether the page lists the steps, each opening on a page of its own,
    /// in place of the step bar.
    var listsSteps = false
    /// Whether the stage carries the step bar; a step's own page has none.
    var showsStepBar = true

    @State private var initialAppearance: SpaceBranding?
    @State private var history: [SpaceBranding] = []
    @State private var editingStart: SpaceBranding?
    /// The look Undo put back, which is not itself a change to remember.
    @State private var restoredBranding: SpaceBranding?

    private var context: BrowserCrestStudioContext {
        BrowserCrestStudioContext(
            branding: $branding,
            defaults: branding.startingLook ?? initialAppearance ?? branding,
            compact: false, previewBranding: editingStart)
    }

    var body: some View {
        BrowserSettingsPane(.spaces) {
            if listsSteps {
                stepList
            } else {
                stepSections
            }
        }
        #if os(iOS)
            .modifier(
                BrowserCrestForgeStepPages(isEnabled: listsSteps) { step in
                    BrowserCrestForge(branding: $branding, symbol: $symbol, step: .constant(step), showsStepBar: false)
                        .navigationTitle(Text(step.title))
                        .navigationBarTitleDisplayMode(.inline)
                })
        #endif
        #if os(macOS)
            .environment(\.browserSettingsColumnWidth, BrowserCrestForgeMetrics.columnWidth)
        #endif
        .environment(
            \.crestStudioEditingChanged,
            BrowserCrestStudioEditingAction { editing in
                // A drag is one change to undo, and the galleries keep their
                // compositions while it runs.
                if editing {
                    if editingStart == nil { editingStart = branding }
                } else if let start = editingStart {
                    editingStart = nil
                    if start != branding { remember(start) }
                }
            }
        )
        .onAppear { if initialAppearance == nil { initialAppearance = branding } }
        .onChange(of: branding) { previous, current in
            if let restored = restoredBranding {
                restoredBranding = nil
                if current == restored { return }
            }
            guard editingStart == nil else { return }
            remember(previous)
        }
        .accessibilityIdentifier("space-customization-controls")
    }

    // MARK: - Steps

    /// The stage over every step, each showing what it has chosen.
    private var stepList: some View {
        Section {
            ForEach(BrowserCrestStudioStep.all) { step in
                NavigationLink(value: step) {
                    LabeledContent {
                        Text(step.summary(branding))
                    } label: {
                        Label {
                            Text(step.title)
                        } icon: {
                            Image(systemName: step.symbol)
                        }
                    }
                }
                .accessibilityIdentifier("space-forge-step-\(step.name)")
            }
        } header: {
            stageHeader
        }
    }

    @ViewBuilder
    private var stepSections: some View {
        switch step.kind {
        case .start:
            startSections
        case .icon:
            iconSections
        case .sidebar:
            sidebarSections
        }
    }

    // MARK: - Step sections

    private var startSections: some View {
        gallery(SpaceHouse.all, id: \.self) { house in
            BrowserCrestStudioChoice(title: house.title, selected: house.isWorn(by: branding), tint: .accentColor) {
                branding = house.applying(to: branding)
            } artwork: {
                BrowserSpaceLookTile(
                    look: house.applying(to: editingStart ?? branding), symbol: symbol,
                    size: BrowserCrestForgeMetrics.tileIconSize)
            }
        } trailing: {
            ForEach(SpaceScheme.all, id: \.self) { scheme in
                BrowserSpaceSchemeChoice(scheme: scheme, branding: $branding, symbol: symbol, tint: .accentColor)
            }
        }
    }

    private var sidebarSections: some View {
        sidebarSection
    }

    private var iconSections: some View {
        Section {
            BrowserSpaceIconChoices(symbol: $symbol, arrangement: .stacked)
            let color = context.setting(\.symbolColor)
            CrestSettingRow("Follow Space color", setting: color.resettable("Icon color")) {
                Toggle(
                    "Follow Space color",
                    isOn: Binding(
                        get: { branding.symbolColor == nil },
                        set: { color.binding.wrappedValue = $0 ? nil : branding.resolvedSymbolColor })
                )
                .labelsHidden()
            }
        } header: {
            stageHeader
        }
    }

    private var sidebarSection: some View {
        Section {
            BrowserCrestStudioFillPicker(context: context)
            BrowserCrestStudioSlider(title: "Intensity", value: context.setting(\.bannerStrength))
            if branding.themeMode == .gradient {
                let angle = context.setting(\.gradientAngle)
                CrestSettingRow("Gradient angle", setting: angle.resettable("Gradient angle")) {
                    HStack(spacing: 12) {
                        Text("\(Int(angle.wrappedValue.rounded()))°").monospacedDigit().foregroundStyle(.secondary)
                        BrowserSpaceGradientAngleDial(angle: angle.binding, color: branding.secondaryColor.color)
                            .frame(width: 44, height: 44)
                    }
                }
            }
            BrowserCrestStudioSlider(title: "Readability fade", value: context.setting(\.readabilityFade))
            BrowserCrestStudioSlider(title: "Folder colors", value: context.setting(\.folderColorIntensity))
            if branding.themeMode == .gradient {
                let texture = context.setting(\.showsTexture)
                CrestSettingRow("Texture", setting: texture.resettable("Texture")) {
                    Toggle("Texture", isOn: texture.binding).labelsHidden()
                }
            }
            segmentedText
        } header: {
            stageHeader
        }
    }

    private var segmentedText: some View {
        let text = context.setting(\.textColorMode)
        return CrestSettingRow("Text", setting: text.resettable("Text")) {
            Picker("Text", selection: text.binding) {
                ForEach(SpaceTextColorMode.all, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            #if os(macOS)
                .fixedSize()
            #endif
        }
    }

    // MARK: - Galleries

    private func gallery<Item, ID: Hashable, Tile: View>(
        _ items: [Item], id: KeyPath<Item, ID>, @ViewBuilder tile: @escaping (Item) -> Tile
    ) -> some View {
        gallery(items, id: id, tile: tile) { EmptyView() }
    }

    /// A gallery of `items`' tiles followed by `trailing` tiles of another kind.
    private func gallery<Item, ID: Hashable, Tile: View, Trailing: View>(
        _ items: [Item], id: KeyPath<Item, ID>, @ViewBuilder tile: @escaping (Item) -> Tile,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        Section {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8
            ) {
                ForEach(items, id: id) { item in tile(item) }
                trailing()
            }
            .padding(.vertical, 4)
            .accessibilityIdentifier("space-forge-gallery")
        } header: {
            stageHeader
        }
    }

    /// The stage and the steps head the page's first section, outside the
    /// grouped boxes, so the icon sits on the Space's field alone.
    private var stageHeader: some View {
        VStack(spacing: 16) {
            BrowserCrestForgeStage(
                branding: $branding, symbol: symbol, name: name, canUndo: !history.isEmpty, shuffle: shuffle,
                undo: undo)
            if showsStepBar && !listsSteps {
                BrowserPlatformCrestForgeStepBar(step: $step)
            }
        }
        .textCase(nil)
        .padding(.bottom, 4)
    }

    // MARK: - History

    private func remember(_ previous: SpaceBranding) {
        history.append(previous)
        if history.count > BrowserCrestForgeHistory.limit { history.removeFirst() }
    }

    private func undo() {
        guard let previous = history.popLast() else { return }
        restoredBranding = previous
        branding = previous
    }

    private func shuffle() {
        branding = Self.shuffledLook(branding)
    }

    // MARK: - Looks

    /// A new sidebar and icon color: one of the templates' gradients, its
    /// first color always darkest so text stays light, its other two in
    /// either order, at an angle that runs down the sidebar, with the
    /// template's own icon color.
    static func shuffledLook(_ branding: SpaceBranding) -> SpaceBranding {
        guard let house = SpaceHouse.all.randomElement() else { return branding }
        var colors = Array(house.look.colors)
        if colors.count == 3, Bool.random() { colors.swapAt(1, 2) }

        var look = branding
        look.themeMode = .gradient
        look.gradientAngle = Double.random(in: 45...135).rounded()
        look.colors = ColorPalette(colors: colors)
        look.symbolColor = house.look.symbolColor
        look.hasCustomAppearance = true
        return look.normalized()
    }
}

private enum BrowserCrestForgeHistory {
    static let limit = 40
}

#if os(iOS)
    /// Opens a listed step on a page of its own, where the Forge lists its steps.
    private struct BrowserCrestForgeStepPages<Page: View>: ViewModifier {
        let isEnabled: Bool
        @ViewBuilder let page: (BrowserCrestStudioStep) -> Page

        func body(content: Content) -> some View {
            if isEnabled {
                content.navigationDestination(for: BrowserCrestStudioStep.self, destination: page)
            } else {
                content
            }
        }
    }
#endif
