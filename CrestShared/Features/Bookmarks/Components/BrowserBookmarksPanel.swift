import SwiftUI

/// The page a bookmarks panel can bookmark: its address and title.
struct BrowserBookmarkPage: Equatable {
    let url: String
    let title: String
}

/// A Space's bookmarks: the page on show, bookmarked or not, a search, and
/// the folders and links, with a new folder a click away. Editing replaces
/// the list until it is saved or cancelled.
struct BrowserBookmarksPanel: View {
    let browser: BrowserStore
    let space: SpaceModel
    let page: BrowserBookmarkPage?
    /// Whether the panel opens straight on bookmarking `page`.
    var startsBookmarkingPage = false
    let dismiss: () -> Void

    @State private var search = ""
    @State private var draft: BrowserBookmarkDraft?

    private var library: BrowserBookmarkLibrary {
        BrowserBookmarkLibrary(space: space, spaces: browser.availableSpaces)
    }

    var body: some View {
        Group {
            if let draft {
                BrowserBookmarkEditor(
                    draft: draft, library: library, save: save,
                    delete: draft.id.map { id in { delete(id, in: draft.spaceID) } },
                    cancel: { self.draft = nil })
            } else {
                list
            }
        }
        .frame(width: BrowserBookmarksPanelMetrics.width)
        .onAppear {
            if startsBookmarkingPage { bookmarkPage() }
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
            pageRow
            TextField("Search Bookmarks", text: $search)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("bookmarks-search")
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    let library = library
                    if search.trimmingCharacters(in: .whitespaces).isEmpty {
                        ForEach(library.roots) { BrowserBookmarkRow(entry: $0, actions: rowActions) }
                    } else {
                        ForEach(library.links(matching: search)) { BrowserBookmarkRow(entry: $0, actions: rowActions) }
                    }
                    if library.roots.isEmpty {
                        Text("Bookmark pages you want to keep without filling your sidebar.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    }
                }
            }
            .frame(maxHeight: BrowserBookmarksPanelMetrics.listHeight)
        }
        .padding(14)
    }

    /// The page on show: bookmarked, with the way to edit it, or a button
    /// that bookmarks it.
    @ViewBuilder private var pageRow: some View {
        if let page {
            if let entry = library.entry(at: page.url) {
                Button {
                    edit(entry)
                } label: {
                    Label("Edit Bookmark for This Page", systemImage: "bookmark.fill")
                }
                .buttonStyle(.borderless)
            } else {
                Button(action: bookmarkPage) {
                    Label("Bookmark This Page", systemImage: "bookmark")
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("bookmarks-add-page")
            }
        }
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
            delete: { entry in delete(entry.id, in: entry.spaceID) })
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
        let url = edited.url?.trimmingCharacters(in: .whitespaces)
        if let id = edited.id {
            browser.editBookmark(
                id, in: edited.spaceID, title: edited.title, url: url, showsInEverySpace: edited.showsInEverySpace)
            if edited.parentID != existingParent(of: id, in: edited.spaceID) {
                browser.moveBookmark(id, in: edited.spaceID, into: edited.parentID)
            }
        } else {
            browser.addBookmark(
                in: edited.spaceID, title: edited.title, url: url, parentID: edited.parentID,
                showsInEverySpace: edited.showsInEverySpace)
        }
        draft = nil
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
