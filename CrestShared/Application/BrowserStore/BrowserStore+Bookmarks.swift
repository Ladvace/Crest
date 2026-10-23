import Foundation

// MARK: - Bookmarks

extension BrowserStore {
    /// Bookmarks `url` in `spaceID` as `id`, or adds a folder when it has
    /// none, inside `parentID` or at the top level, last.
    @discardableResult
    func addBookmark(
        _ id: UUID = UUID(), in spaceID: UUID, title: String, url: String?, parentID: UUID?, showsInEverySpace: Bool
    ) -> Bool {
        family.send(
            AddBookmark(
                workspaceID: family.workspaceID, spaceID: spaceID, bookmarkID: id, parentID: parentID,
                beforeID: nil, title: title, url: url, showsInEverySpace: showsInEverySpace),
            from: self)
    }

    /// Bookmarks `url` in `spaceID` inside the folders `folders` name,
    /// outermost first, finding each by name whatever its case and adding
    /// each that's missing. Answers the new bookmark, or nil when the core
    /// refused a step; the folders added before it stay.
    func addBookmark(_ url: String, titled title: String, in spaceID: UUID, folders: [String]) -> UUID? {
        var parentID: UUID?
        guard placeBookmarkFolders(folders, in: spaceID, parentID: &parentID) else { return nil }
        let id = UUID()
        guard addBookmark(id, in: spaceID, title: title, url: url, parentID: parentID, showsInEverySpace: false)
        else { return nil }
        return id
    }

    /// Moves bookmark `id` into the folders `folders` name, outermost first,
    /// or to the top level when they name none, finding or adding each as
    /// bookmarking does. Answers whether the core took every step.
    @discardableResult
    func moveBookmark(_ id: UUID, in spaceID: UUID, intoFolders folders: [String]) -> Bool {
        var parentID: UUID?
        guard placeBookmarkFolders(folders, in: spaceID, parentID: &parentID) else { return false }
        guard spaceModel(spaceID)?.bookmarks.first(where: { $0.id == id })?.parentID != parentID else { return true }
        return moveBookmark(id, in: spaceID, into: parentID)
    }

    @discardableResult
    func editBookmark(
        _ id: UUID, in spaceID: UUID, title: String, url: String?, showsInEverySpace: Bool
    ) -> Bool {
        family.send(
            EditBookmark(
                workspaceID: family.workspaceID, spaceID: spaceID, bookmarkID: id, title: title, url: url,
                showsInEverySpace: showsInEverySpace),
            from: self)
    }

    /// Moves a bookmark, with everything inside it, into `parentID` or to the
    /// top level, before `beforeID` or last.
    @discardableResult
    func moveBookmark(_ id: UUID, in spaceID: UUID, into parentID: UUID?, before beforeID: UUID? = nil) -> Bool {
        family.send(
            MoveBookmark(
                workspaceID: family.workspaceID, spaceID: spaceID, bookmarkID: id, parentID: parentID,
                beforeID: beforeID),
            from: self)
    }

    @discardableResult
    func deleteBookmark(_ id: UUID, in spaceID: UUID) -> Bool {
        family.send(
            DeleteBookmark(workspaceID: family.workspaceID, spaceID: spaceID, bookmarkID: id),
            from: self)
    }

    // MARK: - Folder Paths

    /// Finds or adds each folder `folders` names, outermost first, leaving
    /// the innermost in `parentID`. Answers false when the core refused one.
    private func placeBookmarkFolders(_ folders: [String], in spaceID: UUID, parentID: inout UUID?) -> Bool {
        for name in folders {
            let bookmarks = spaceModel(spaceID)?.bookmarks ?? []
            if let folder = bookmarks.first(where: {
                $0.isFolder && $0.parentID == parentID && $0.title.caseInsensitiveCompare(name) == .orderedSame
            }) {
                parentID = folder.id
                continue
            }
            let id = UUID()
            guard addBookmark(id, in: spaceID, title: name, url: nil, parentID: parentID, showsInEverySpace: false)
            else { return false }
            parentID = id
        }
        return true
    }
}
