import Foundation

/// The steps of making a Space's look: the Forge's step bar on the Mac, and
/// the Studio's groups everywhere.
struct BrowserCrestStudioStep: Hashable, Identifiable, Sendable {
    // MARK: - Types

    /// Each step shows its own choices. ``BrowserCrestForge`` switches on the
    /// kind to choose that step's concrete sections.
    enum Kinds: Sendable {
        case start
        case icon
        case sidebar
    }

    // MARK: - Static Variables

    static let start = BrowserCrestStudioStep(
        kind: .start, name: "start", title: "Start from", symbol: "sparkles",
        summary: { branding in SpaceHouse.all.first { $0.isWorn(by: branding) }?.title ?? "Custom" })
    static let icon = BrowserCrestStudioStep(
        kind: .icon, name: "icon", title: "Icon", symbol: "face.smiling",
        summary: { $0.symbolColor == nil ? "Space color" : "Custom color" })
    static let sidebar = BrowserCrestStudioStep(
        kind: .sidebar, name: "sidebar", title: "Sidebar", symbol: "sidebar.left",
        summary: { $0.themeMode == .gradient ? "Gradient" : $0.bannerPattern.title })

    /// Every step, in the step bar's order.
    static let all: [BrowserCrestStudioStep] = [start, icon, sidebar]

    // MARK: - Variables

    let kind: Kinds
    let name: String
    let title: LocalizedStringResource
    let symbol: String

    /// What a branding has chosen at this step, in a word or two.
    let summary: @Sendable (SpaceBranding) -> LocalizedStringResource

    var id: String { name }

    // MARK: - Initializers

    private init(
        kind: Kinds, name: String, title: LocalizedStringResource, symbol: String,
        summary: @escaping @Sendable (SpaceBranding) -> LocalizedStringResource
    ) {
        self.kind = kind
        self.name = name
        self.title = title
        self.symbol = symbol
        self.summary = summary
    }

    // MARK: - Actions - Identity

    static func == (lhs: BrowserCrestStudioStep, rhs: BrowserCrestStudioStep) -> Bool {
        lhs.name == rhs.name
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}
