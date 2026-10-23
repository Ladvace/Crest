import SwiftUI
import UniformTypeIdentifiers

/// A Space's bookmarks as a slim bar above its pages: each top-level link
/// with its site's icon, and each folder as a menu of what it holds. A click
/// opens a link in the tab on show; the link's menu opens it in a new one or
/// deletes it. What doesn't fit gathers in a "+N" menu at the end, and the
/// Space's own bookmarks reorder by dragging.
struct BrowserBookmarksBar: View {
    let browser: BrowserStore
    let space: SpaceModel
    /// Opens an address, in a new tab when the flag says so.
    let open: (URL, Bool) -> Void

    /// Each top-level bookmark's width on the bar, measured off screen.
    @State private var widths: [UUID: CGFloat] = [:]
    @State private var availableWidth: CGFloat = 0
    /// The bookmark being dragged along the bar.
    @State private var dragged: UUID?
    @State private var pendingDeletion: BrowserBookmarkDeletion?

    var body: some View {
        let roots = BrowserBookmarkLibrary(space: space, spaces: browser.availableSpaces).roots
        let shown = shownCount(of: roots)
        HStack(spacing: BrowserBookmarksBarMetrics.spacing) {
            ForEach(roots.prefix(shown)) { entry in
                item(entry)
                    .modifier(
                        BrowserBookmarksBarReorder(
                            entry: entry, order: ownOrder(of: roots), isMovable: entry.spaceID == space.id,
                            dragged: $dragged, move: move))
            }
            if shown < roots.count {
                overflow(Array(roots.dropFirst(shown)))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, BrowserBookmarksBarMetrics.inset)
        .frame(maxWidth: .infinity)
        .frame(height: BrowserBookmarksBarMetrics.height)
        .onGeometryChange(for: CGFloat.self) {
            $0.size.width - 2 * BrowserBookmarksBarMetrics.inset
        } action: {
            availableWidth = $0
        }
        .background { measurements(of: roots) }
        .bookmarkDeletionConfirmation($pendingDeletion) { browser.deleteBookmark($0.id, in: $0.spaceID) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Bookmarks Bar")
        .accessibilityIdentifier("browser-bookmarks-bar")
    }

    // MARK: - Items

    @ViewBuilder private func item(_ entry: BrowserBookmarkLibrary.Entry) -> some View {
        if let children = entry.children {
            Menu {
                BrowserBookmarkMenuItems(entries: children, open: open)
            } label: {
                label(of: entry)
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(BrowserBookmarksBarItemStyle())
            .contextMenu { deleteButton(entry) }
        } else if let url = entry.bookmark.url.flatMap(URL.init(string:)) {
            Button {
                open(url, false)
            } label: {
                label(of: entry)
            }
            .buttonStyle(BrowserBookmarksBarItemStyle())
            .help(entry.bookmark.url ?? "")
            .contextMenu {
                Button("Open in New Tab") { open(url, true) }
                Divider()
                deleteButton(entry)
            }
        }
    }

    private func deleteButton(_ entry: BrowserBookmarkLibrary.Entry) -> some View {
        Button("Delete…", role: .destructive) { pendingDeletion = BrowserBookmarkDeletion(entry) }
    }

    /// The bookmarks that didn't fit, as one menu at the end of the bar.
    private func overflow(_ hidden: [BrowserBookmarkLibrary.Entry]) -> some View {
        Menu {
            BrowserBookmarkMenuItems(entries: hidden, open: open)
        } label: {
            Text("+\(hidden.count)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(BrowserBookmarksBarItemStyle())
        .fixedSize()
        .help("More Bookmarks")
        .accessibilityLabel(Text("\(hidden.count) More Bookmarks"))
        .accessibilityIdentifier("browser-bookmarks-bar-overflow")
    }

    private func label(of entry: BrowserBookmarkLibrary.Entry) -> some View {
        HStack(spacing: 6) {
            Group {
                if entry.children != nil {
                    Image(systemName: "folder").foregroundStyle(.secondary)
                } else if let url = entry.bookmark.url.flatMap(URL.init(string:)) {
                    BrowserBookmarkFavicon(url: url, browser: browser)
                }
            }
            .frame(width: 14, height: 14)
            Text(entry.bookmark.title)
                .lineLimit(1)
                .frame(maxWidth: BrowserBookmarksBarMetrics.titleWidth, alignment: .leading)
                .fixedSize(horizontal: true, vertical: false)
        }
        .font(.system(size: 12))
    }

    // MARK: - Fitting

    /// Every item at its natural width, hidden, so the bar knows what fits.
    private func measurements(of roots: [BrowserBookmarkLibrary.Entry]) -> some View {
        HStack(spacing: BrowserBookmarksBarMetrics.spacing) {
            ForEach(roots) { entry in
                label(of: entry)
                    .padding(.horizontal, BrowserBookmarksBarMetrics.itemPadding)
                    .fixedSize()
                    .onGeometryChange(for: CGFloat.self) {
                        $0.size.width
                    } action: {
                        widths[entry.id] = $0
                    }
            }
        }
        .fixedSize()
        .hidden()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// How many bookmarks fit in order, leaving room for the "+N" menu when
    /// some don't.
    private func shownCount(of roots: [BrowserBookmarkLibrary.Entry]) -> Int {
        guard availableWidth > 0 else { return roots.count }
        let spacing = BrowserBookmarksBarMetrics.spacing
        let width = { (entry: BrowserBookmarkLibrary.Entry) in
            widths[entry.id] ?? BrowserBookmarksBarMetrics.titleWidth
        }
        let total = roots.map(width).reduce(0, +) + spacing * CGFloat(max(roots.count - 1, 0))
        if total <= availableWidth { return roots.count }
        let room = availableWidth - spacing - BrowserBookmarksBarMetrics.overflowWidth
        var used: CGFloat = 0
        for (index, entry) in roots.enumerated() {
            used += (index > 0 ? spacing : 0) + width(entry)
            if used > room { return index }
        }
        return roots.count
    }

    // MARK: - Reordering

    /// The Space's own top-level bookmarks in bar order; those other Spaces
    /// share stay where their Space keeps them.
    private func ownOrder(of roots: [BrowserBookmarkLibrary.Entry]) -> [UUID] {
        roots.filter { $0.spaceID == space.id }.map(\.id)
    }

    /// Moves bookmark `id` to where `target` stands: after it when it came
    /// from before it, otherwise before it.
    private func move(_ id: UUID, to target: UUID, in order: [UUID]) {
        guard let from = order.firstIndex(of: id), let to = order.firstIndex(of: target), from != to else { return }
        let before = from < to ? (to + 1 < order.count ? order[to + 1] : nil) : target
        withAnimation(.snappy(duration: CrestMotion.hoverTransition)) {
            _ = browser.moveBookmark(id, in: space.id, into: nil, before: before)
        }
    }
}

/// Lets one of a Space's own bookmarks be dragged along the bar. It moves
/// live as it passes over another, so the bar shows the order as it forms.
private struct BrowserBookmarksBarReorder: ViewModifier {
    let entry: BrowserBookmarkLibrary.Entry
    let order: [UUID]
    let isMovable: Bool
    @Binding var dragged: UUID?
    let move: (UUID, UUID, [UUID]) -> Void

    func body(content: Content) -> some View {
        if isMovable {
            content
                .onDrag {
                    dragged = entry.id
                    let binding = $dragged
                    return NSItemProvider(
                        object: BrowserBookmarkDragPayload(id: entry.id) { id in
                            if binding.wrappedValue == id { binding.wrappedValue = nil }
                        })
                }
                .onDrop(
                    of: [.plainText],
                    delegate: Drop(target: entry.id, order: order, dragged: $dragged, move: move))
        } else {
            content
        }
    }

    private struct Drop: DropDelegate {
        let target: UUID
        let order: [UUID]
        @Binding var dragged: UUID?
        let move: (UUID, UUID, [UUID]) -> Void

        func validateDrop(info: DropInfo) -> Bool { dragged != nil }

        func dropEntered(info: DropInfo) {
            guard let dragged, dragged != target else { return }
            move(dragged, target, order)
        }

        func dropUpdated(info: DropInfo) -> DropProposal? {
            DropProposal(operation: .move)
        }

        func performDrop(info: DropInfo) -> Bool {
            dragged = nil
            return true
        }
    }
}

/// What a bookmark drag carries: the bookmark's identity, as text. The drag
/// session holds it while the drag lasts, so when it lets go, wherever the
/// drag ended, the bar forgets the bookmark it was moving and a later drag of
/// other text can't move it.
private final class BrowserBookmarkDragPayload: NSObject, NSItemProviderWriting {
    static var writableTypeIdentifiersForItemProvider: [String] { [UTType.plainText.identifier] }

    private let id: UUID
    private let ended: @MainActor (UUID) -> Void

    init(id: UUID, ended: @escaping @MainActor (UUID) -> Void) {
        self.id = id
        self.ended = ended
    }

    deinit {
        let (id, ended) = (id, ended)
        Task { @MainActor in ended(id) }
    }

    func loadData(
        withTypeIdentifier typeIdentifier: String,
        forItemProviderCompletionHandler completionHandler: @escaping @Sendable (Data?, (any Error)?) -> Void
    ) -> Progress? {
        completionHandler(Data(id.uuidString.utf8), nil)
        return nil
    }
}

/// The links and folders inside a bookmarks folder, as menu items, each
/// folder a submenu of its own.
private struct BrowserBookmarkMenuItems: View {
    let entries: [BrowserBookmarkLibrary.Entry]
    let open: (URL, Bool) -> Void

    var body: some View {
        ForEach(entries) { entry in
            if let children = entry.children {
                Menu(entry.bookmark.title) {
                    BrowserBookmarkMenuItems(entries: children, open: open)
                }
            } else if let url = entry.bookmark.url.flatMap(URL.init(string:)) {
                Button(entry.bookmark.title) { open(url, false) }
            }
        }
        if entries.isEmpty {
            Text("Empty").foregroundStyle(.secondary)
        }
    }
}

/// A bookmark's site icon: the icon of a tab the Spaces have open on the same
/// site, or a globe while none does.
private struct BrowserBookmarkFavicon: View {
    let url: URL
    let browser: BrowserStore

    var body: some View {
        if let tab = tabOnSameSite {
            TabFaviconView(
                subject: BrowserTabFaviconSubject(tab: tab, image: browser.core.state.favicons.icon(of: tab.id)),
                size: 14)
        } else {
            Image(systemName: "globe").foregroundStyle(.secondary)
        }
    }

    private var tabOnSameSite: TabStateModel? {
        guard let host = url.host() else { return nil }
        for space in browser.availableSpaces {
            if let tab = space.tabs.models.first(where: { $0.url.flatMap(URL.init(string:))?.host() == host }) {
                return tab
            }
        }
        return nil
    }
}

/// A bar item's quiet surface: nothing at rest, the design system's hover
/// and press tints.
private struct BrowserBookmarksBarItemStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        BrowserBookmarksBarItem(configuration: configuration)
    }

    private struct BrowserBookmarksBarItem: View {
        let configuration: ButtonStyleConfiguration
        @State private var isHovering = false

        var body: some View {
            configuration.label
                .padding(.horizontal, BrowserBookmarksBarMetrics.itemPadding)
                .frame(height: BrowserBookmarksBarMetrics.itemHeight)
                .crestInteractiveSurface(
                    isSelected: false, isHovering: isHovering, cornerRadius: CrestRadius.compact,
                    isPressed: configuration.isPressed
                )
                .contentShape(.rect)
                .onHover { isHovering = $0 }
        }
    }
}

/// Whether the window shows the bookmarks bar, a choice for the whole device.
enum BrowserBookmarksBarPreference {
    static let key = "crest.appearance.showsBookmarksBar"
    static let defaultValue = true

    /// Shows the bar where it was hidden, or hides it.
    static func toggle(in defaults: UserDefaults = .standard) {
        defaults.set(!(defaults.object(forKey: key) as? Bool ?? defaultValue), forKey: key)
    }
}

enum BrowserBookmarksBarMetrics {
    static let height: CGFloat = 30
    static let itemHeight: CGFloat = 24
    static let titleWidth: CGFloat = 140
    static let itemPadding: CGFloat = 8
    static let spacing: CGFloat = 2
    static let inset: CGFloat = 4
    /// Room the "+N" menu takes at the end of a full bar.
    static let overflowWidth: CGFloat = 40
}
