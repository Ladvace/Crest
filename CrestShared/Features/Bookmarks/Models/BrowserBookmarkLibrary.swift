import Foundation

/// The bookmarks a Space's library shows: its own, then those other Spaces
/// show in every Space, each with the Space that keeps it.
struct BrowserBookmarkLibrary {
    // MARK: - Types

    /// One bookmark in the library, with the folders and links inside it.
    struct Entry: Identifiable, Equatable {
        let bookmark: BookmarkState
        /// The Space that keeps the bookmark, which edits go to.
        let spaceID: UUID
        /// What a folder holds, or nil for a link.
        let children: [Entry]?

        var id: UUID { bookmark.id }
    }

    // MARK: - Variables

    let spaceID: UUID
    let roots: [Entry]
    /// The bookmarks the Space keeps itself.
    private let own: [BookmarkState]

    // MARK: - Initializers

    @MainActor
    init(space: SpaceModel, spaces: [SpaceModel]) {
        spaceID = space.id
        own = space.bookmarks
        var roots = Self.entries(in: space.bookmarks, spaceID: space.id, parent: nil)
        for other in spaces where other.id != space.id {
            let shared = other.bookmarks.filter {
                $0.showsInEverySpace && !Self.sitsInSharedFolder($0, among: other.bookmarks)
            }
            roots += shared.map { Self.entry($0, in: other.bookmarks, spaceID: other.id) }
        }
        self.roots = roots
    }

    // MARK: - Actions - Reading

    /// The bookmark the library keeps for the page at `url`, if any.
    func entry(at url: String?) -> Entry? {
        guard let key = url.flatMap(Self.key(of:)) else { return nil }
        return links.first { $0.bookmark.url.flatMap(Self.key(of:)) == key }
    }

    /// Every link whose title or address holds `query`, ignoring case.
    func links(matching query: String) -> [Entry] {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [] }
        return links.filter {
            $0.bookmark.title.localizedCaseInsensitiveContains(query)
                || $0.bookmark.url?.localizedCaseInsensitiveContains(query) == true
        }
    }

    /// The Space's own folders in the order they show, each with how deep it
    /// sits, leaving out `excluded` and everything inside it.
    func folders(excluding excluded: UUID? = nil) -> [(folder: BookmarkState, depth: Int)] {
        var result: [(BookmarkState, Int)] = []
        func append(_ parent: UUID?, depth: Int) {
            for bookmark in own where bookmark.parentID == parent && bookmark.isFolder && bookmark.id != excluded {
                result.append((bookmark, depth))
                append(bookmark.id, depth: depth + 1)
            }
        }
        append(nil, depth: 0)
        return result
    }

    private var links: [Entry] {
        var result: [Entry] = []
        func collect(_ entries: [Entry]) {
            for entry in entries {
                if let children = entry.children { collect(children) } else { result.append(entry) }
            }
        }
        collect(roots)
        return result
    }

    private static func entries(in bookmarks: [BookmarkState], spaceID: UUID, parent: UUID?) -> [Entry] {
        bookmarks.filter { $0.parentID == parent }.map { entry($0, in: bookmarks, spaceID: spaceID) }
    }

    private static func entry(_ bookmark: BookmarkState, in bookmarks: [BookmarkState], spaceID: UUID) -> Entry {
        Entry(
            bookmark: bookmark, spaceID: spaceID,
            children: bookmark.isFolder ? entries(in: bookmarks, spaceID: spaceID, parent: bookmark.id) : nil)
    }

    /// Whether a folder around `bookmark` is already shown in every Space,
    /// which brings it along.
    private static func sitsInSharedFolder(_ bookmark: BookmarkState, among bookmarks: [BookmarkState]) -> Bool {
        var parentID = bookmark.parentID
        while let id = parentID, let parent = bookmarks.first(where: { $0.id == id }) {
            if parent.showsInEverySpace { return true }
            parentID = parent.parentID
        }
        return false
    }

    /// The address two bookmarks of one page share: without its fragment or
    /// a trailing slash, ignoring case in the scheme and host.
    private static func key(of url: String) -> String? {
        guard var components = URLComponents(string: url) else { return nil }
        components.fragment = nil
        components.scheme = components.scheme?.lowercased()
        components.host = components.host?.lowercased()
        guard var spelled = components.string else { return nil }
        if spelled.hasSuffix("/") { spelled.removeLast() }
        return spelled
    }
}
