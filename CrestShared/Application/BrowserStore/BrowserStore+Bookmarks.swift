import Foundation

// MARK: - Bookmarks

extension BrowserStore {
    /// Bookmarks `url` in `spaceID`, or adds a folder when it has none,
    /// inside `parentID` or at the top level, last.
    @discardableResult
    func addBookmark(
        in spaceID: UUID, title: String, url: String?, parentID: UUID?, showsInEverySpace: Bool
    ) -> Bool {
        family.send(
            AddBookmark(
                workspaceID: family.workspaceID, spaceID: spaceID, bookmarkID: UUID(), parentID: parentID,
                beforeID: nil, title: title, url: url, showsInEverySpace: showsInEverySpace),
            from: self)
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
    /// top level, last.
    @discardableResult
    func moveBookmark(_ id: UUID, in spaceID: UUID, into parentID: UUID?) -> Bool {
        family.send(
            MoveBookmark(
                workspaceID: family.workspaceID, spaceID: spaceID, bookmarkID: id, parentID: parentID, beforeID: nil),
            from: self)
    }

    @discardableResult
    func deleteBookmark(_ id: UUID, in spaceID: UUID) -> Bool {
        family.send(
            DeleteBookmark(workspaceID: family.workspaceID, spaceID: spaceID, bookmarkID: id),
            from: self)
    }
}
