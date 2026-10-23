import SwiftUI

/// The page a bookmarks panel can bookmark: its address and title.
struct BrowserBookmarkPage: Equatable {
    let url: String
    let title: String
}

/// A Space's bookmarks: one bar, opened on the page on show, that searches
/// the folders and links below it as it changes and bookmarks what it names,
/// with a new folder a click away. Editing replaces the list until it is
/// saved or cancelled.
struct BrowserBookmarksPanel: View {
    let browser: BrowserStore
    let space: SpaceModel
    let page: BrowserBookmarkPage?
    /// Whether the panel opens straight on bookmarking `page`.
    var startsBookmarkingPage = false
    let dismiss: () -> Void

    @State private var entry = ""
    /// Why the bar's last save failed, until the bar changes.
    @State private var entryFailure: String?
    @State private var draft: BrowserBookmarkDraft?
    @State private var expanded: Set<UUID> = []
    /// The bookmark last saved, shown open and pointed out in the list.
    @State private var saved: UUID?
    /// The bookmark waiting for the person to confirm its deletion.
    @State private var pendingDeletion: BrowserBookmarkDeletion?
    @FocusState private var focusesEntry: Bool

    private var library: BrowserBookmarkLibrary {
        BrowserBookmarkLibrary(space: space, spaces: browser.availableSpaces)
    }

    var body: some View {
        Group {
            if let draft {
                BrowserBookmarkEditor(
                    draft: draft, library: library, save: save,
                    delete: BrowserBookmarkDeletion(draft).map { deletion in { pendingDeletion = deletion } },
                    cancel: { self.draft = nil })
            } else {
                list
            }
        }
        .frame(width: BrowserBookmarksPanelMetrics.width)
        .bookmarkDeletionConfirmation($pendingDeletion) { delete($0.id, in: $0.spaceID) }
        .onAppear {
            if startsBookmarkingPage {
                bookmarkPage()
            } else {
                entry = suggestion
                focusesEntry = true
            }
        }
    }

    // MARK: - Sections

    private var list: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Bookmarks").font(.headline)
                Spacer()
                Button("New Folder", systemImage: "folder.badge.plus") {
                    draft = BrowserBookmarkDraft(
                        id: nil, spaceID: space.id, title: "", url: nil, parentID: nil, showsInEverySpace: false)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(CrestChromeButtonStyle())
                .help("New Folder")
                .accessibilityIdentifier("bookmarks-new-folder")
            }
            bar
            ScrollViewReader { reader in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        let library = library
                        let disclosure = BrowserBookmarkRowDisclosure(expanded: $expanded, highlighted: saved)
                        if search.isEmpty {
                            ForEach(library.roots) {
                                BrowserBookmarkRow(entry: $0, actions: rowActions, disclosure: disclosure)
                            }
                        } else {
                            ForEach(library.links(matching: search)) {
                                BrowserBookmarkRow(entry: $0, actions: rowActions, disclosure: disclosure)
                            }
                        }
                        if library.roots.isEmpty {
                            Text("Bookmark pages you want to keep without filling your sidebar.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        }
                    }
                }
                .onChange(of: saved, initial: true) { _, id in
                    guard let id else { return }
                    withAnimation { reader.scrollTo(id, anchor: .center) }
                }
            }
            .frame(maxHeight: BrowserBookmarksPanelMetrics.listHeight)
        }
        .padding(14)
    }

    /// The bar: it opens on the page on show, `recipes/vegan/` puts that page
    /// in those folders, `recipes/vegan/soup.example` bookmarks that address
    /// there, making each folder that's missing, and a bookmark already kept
    /// moves instead. Words alone only search. Return saves, as the button
    /// does.
    private var bar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                TextField("Search, or save as folder/example.com", text: $entry)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusesEntry)
                    .onSubmit(saveEntry)
                    .onChange(of: entry) { entryFailure = nil }
                    .accessibilityIdentifier("bookmarks-search")
                Button("Save", action: saveEntry)
                    .disabled(entryTarget == nil)
                    .accessibilityIdentifier("bookmarks-quick-save")
            }
            if let entryFailure {
                Text(entryFailure)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            } else if let target = entryTarget {
                let place = target.folders.isEmpty ? "Bookmarks" : target.folders.joined(separator: " › ")
                Text(caption(for: target, in: place))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    /// An address as the bar's preview names it: the page on show by its
    /// title, any other by its site.
    private func displayed(_ url: String) -> String {
        if url == page?.url, let title = page?.title, !title.isEmpty { return title }
        return URL(string: url)?.host() ?? url
    }

    // MARK: - Actions

    private var rowActions: BrowserBookmarkRowActions {
        BrowserBookmarkRowActions(
            open: { entry, newTab in
                guard let url = entry.bookmark.url.flatMap(URL.init(string:)) else { return }
                if newTab {
                    _ = browser.openNewTab(url: url, in: space.id)
                } else {
                    browser.openAddress(url, in: space.id)
                }
                dismiss()
            },
            edit: edit,
            toggleShared: { entry in
                browser.editBookmark(
                    entry.id, in: entry.spaceID, title: entry.bookmark.title, url: entry.bookmark.url,
                    showsInEverySpace: !entry.bookmark.showsInEverySpace)
            },
            delete: { entry in pendingDeletion = BrowserBookmarkDeletion(entry) },
            addInside: { folder, makesFolder in
                let suggestsPage = !makesFolder && page.map { library.entry(at: $0.url) == nil } == true
                draft = BrowserBookmarkDraft(
                    id: nil, spaceID: folder.spaceID, title: suggestsPage ? page?.title ?? "" : "",
                    url: makesFolder ? nil : suggestsPage ? page?.url ?? "" : "",
                    parentID: folder.id, showsInEverySpace: false)
            })
    }

    /// Where the bar would bookmark: the folders it names and the address,
    /// its own or the page on show's, or nil when it names nothing to
    /// bookmark, as words without a "/" or an address don't.
    private var entryTarget: (folders: [String], url: String)? {
        guard let path = BrowserBookmarkPath(entry), path.url != nil || entry.contains("/") else { return nil }
        guard let url = path.url ?? page?.url else { return nil }
        return (path.folders, url)
    }

    /// What the bar opens holding: the page on show's address, after the
    /// folders that keep it when it's bookmarked.
    private var suggestion: String {
        guard let page else { return "" }
        let folders = ownEntry(at: page.url).map { folderPath(of: $0.id) } ?? []
        return (folders + [Self.spelled(page.url)]).joined(separator: "/")
    }

    /// The names of the folders around bookmark `id`, outermost first.
    private func folderPath(of id: UUID) -> [String] {
        let bookmarks = browser.availableSpaces.first { $0.id == space.id }?.bookmarks ?? []
        var names: [String] = []
        var parentID = existingParent(of: id, in: space.id)
        while let folderID = parentID {
            names.insert(bookmarks.first { $0.id == folderID }?.title ?? "", at: 0)
            parentID = existingParent(of: folderID, in: space.id)
        }
        return names
    }

    /// What saving `target` would do: save it, move the bookmark already
    /// kept for it, or nothing when it already sits in `place`.
    private func caption(for target: (folders: [String], url: String), in place: String) -> LocalizedStringKey {
        guard let kept = ownEntry(at: target.url) else { return "Saves \(displayed(target.url)) in \(place)" }
        let current = folderPath(of: kept.id)
        let unmoved =
            current.count == target.folders.count
            && zip(current, target.folders).allSatisfy { $0.caseInsensitiveCompare($1) == .orderedSame }
        return unmoved ? "Saved in \(place)" : "Moves \(displayed(target.url)) to \(place)"
    }

    /// What the list is narrowed to: nothing while the bar holds what it
    /// opened with or only folders, the address it names, or its words.
    private var search: String {
        let typed = entry.trimmingCharacters(in: .whitespaces)
        guard typed != suggestion else { return "" }
        guard let path = BrowserBookmarkPath(typed), path.url != nil || typed.contains("/") else { return typed }
        return path.address
    }

    /// The bookmark this Space keeps itself for the page at `url`, if any.
    private func ownEntry(at url: String) -> BrowserBookmarkLibrary.Entry? {
        library.entry(at: url).flatMap { $0.spaceID == space.id ? $0 : nil }
    }

    private func saveEntry() {
        guard let target = entryTarget else { return }
        let id: UUID
        if let kept = ownEntry(at: target.url) {
            guard browser.moveBookmark(kept.id, in: space.id, intoFolders: target.folders) else {
                entryFailure =
                    browser.localSyncErrorDescription ?? String(localized: "Crest couldn't move this bookmark.")
                return
            }
            id = kept.id
        } else {
            let title =
                target.url == page?.url ? page?.title ?? target.url : URL(string: target.url)?.host() ?? target.url
            guard let added = browser.addBookmark(target.url, titled: title, in: space.id, folders: target.folders)
            else {
                entryFailure =
                    browser.localSyncErrorDescription ?? String(localized: "Crest couldn't save this bookmark.")
                return
            }
            id = added
        }
        reveal(id, in: space.id)
    }

    /// An address as the bar spells it: without `https://`, unless the
    /// address it spells would then differ.
    private static func spelled(_ url: String) -> String {
        let prefix = "https://"
        guard url.hasPrefix(prefix) else { return url }
        let short = String(url.dropFirst(prefix.count))
        return BrowserBookmarkPath(short).flatMap { $0.folders.isEmpty && $0.url == url ? short : nil } ?? url
    }

    private func bookmarkPage() {
        guard let page else { return }
        if let entry = library.entry(at: page.url) {
            edit(entry)
            return
        }
        draft = BrowserBookmarkDraft(
            id: nil, spaceID: space.id, title: page.title, url: page.url, parentID: nil, showsInEverySpace: false)
    }

    private func edit(_ entry: BrowserBookmarkLibrary.Entry) {
        draft = BrowserBookmarkDraft(
            id: entry.id, spaceID: entry.spaceID, title: entry.bookmark.title, url: entry.bookmark.url,
            parentID: entry.bookmark.parentID, showsInEverySpace: entry.bookmark.showsInEverySpace)
    }

    private func save(_ edited: BrowserBookmarkDraft) {
        let url = edited.resolvedURL
        let id = edited.id ?? UUID()
        if edited.id != nil {
            browser.editBookmark(
                id, in: edited.spaceID, title: edited.resolvedTitle, url: url,
                showsInEverySpace: edited.showsInEverySpace)
            if edited.parentID != existingParent(of: id, in: edited.spaceID) {
                browser.moveBookmark(id, in: edited.spaceID, into: edited.parentID)
            }
        } else {
            browser.addBookmark(
                id, in: edited.spaceID, title: edited.resolvedTitle, url: url, parentID: edited.parentID,
                showsInEverySpace: edited.showsInEverySpace)
        }
        draft = nil
        reveal(id, in: edited.spaceID)
    }

    /// Opens every folder around bookmark `id`, sets the bar back to the page
    /// on show and
    /// points the bookmark out, so what was just saved is in view.
    private func reveal(_ id: UUID, in spaceID: UUID) {
        entry = suggestion
        var parentID = existingParent(of: id, in: spaceID)
        while let folderID = parentID {
            expanded.insert(folderID)
            parentID = existingParent(of: folderID, in: spaceID)
        }
        saved = id
    }

    private func existingParent(of id: UUID, in spaceID: UUID) -> UUID? {
        browser.availableSpaces.first { $0.id == spaceID }?.bookmarks.first { $0.id == id }?.parentID
    }

    private func delete(_ id: UUID, in spaceID: UUID) {
        browser.deleteBookmark(id, in: spaceID)
        draft = nil
    }
}

enum BrowserBookmarksPanelMetrics {
    static let width: CGFloat = 320
    static let listHeight: CGFloat = 360
}
