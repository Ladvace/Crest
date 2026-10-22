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
    @State private var choosesEmoji = false

    private var context: BrowserCrestStudioContext {
        BrowserCrestStudioContext(
            branding: $branding,
            defaults: SpaceHouse.startingPoint(of: branding)?.look ?? initialAppearance ?? branding,
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
                houseArtwork(house.applying(to: editingStart ?? branding))
            }
        }
    }

    private var sidebarSections: some View {
        sidebarSection
    }

    private var iconSections: some View {
        Section {
            BrowserSystemSymbolPicker(
                selection: Binding(
                    get: { BrowserIconSymbol.emoji(from: symbol) == nil ? symbol : "" },
                    set: { symbol = $0 }))
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
                Text("Automatic").tag(SpaceTextColorMode.automatic)
                Text("Light").tag(SpaceTextColorMode.light)
                Text("Dark").tag(SpaceTextColorMode.dark)
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
        Section {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8
            ) {
                ForEach(items, id: id) { item in tile(item) }
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

    /// A house's tile: its sidebar field under the Space's icon in its colors.
    private func houseArtwork(_ look: SpaceBranding) -> some View {
        BrowserCrestStudioMark(branding: look, symbol: symbol, size: BrowserCrestForgeMetrics.tileIconSize * 0.7)
            .frame(width: BrowserCrestForgeMetrics.tileIconSize, height: BrowserCrestForgeMetrics.tileIconSize)
            .background { BrowserSpaceBannerBackground(branding: look) }
            .clipShape(.rect(cornerRadius: 8))
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

    /// A new sidebar and icon color, chosen afresh in the templates'
    /// tinctures: dark ones for the sidebar's gradient, so its text stays
    /// light, and a light one for the icon on it.
    static func shuffledLook(_ branding: SpaceBranding) -> SpaceBranding {
        let tinctures = Tincture.all.map(\.color)
        let darks = tinctures.filter { $0.luminance < 0.3 }.shuffled()
        let lights = tinctures.filter { $0.luminance > 0.42 }.shuffled()
        guard darks.count > 2, let light = lights.first else { return branding }

        var look = branding
        look.themeMode = .gradient
        look.gradientAngle = Double(Int.random(in: 0..<8) * 45)
        look.colors = [darks[0], darks[1], darks[2]]
        look.symbolColor = light
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
