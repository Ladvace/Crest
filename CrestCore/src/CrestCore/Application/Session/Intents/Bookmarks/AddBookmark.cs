using CrestCore.Application;

namespace CrestCore.Contracts;

/// Bookmarks `Url` in the Space, titled `Title`, inside the folder `ParentId`
/// or at the top level, before `BeforeId` or last. Without an address it adds
/// a folder. A blank title names a link for its address and a folder
/// "Untitled Folder".
public sealed record AddBookmark(Guid WorkspaceId, Guid SpaceId, Guid BookmarkId, Guid? ParentId, Guid? BeforeId, string Title,
    string? Url, bool ShowsInEverySpace) : SessionIntent(WorkspaceId) {
    #region Actions - Session

    internal override SessionEdit? Edit(NativeSessionAuthority workspace, SessionTurn turn) =>
        workspace.Bookmarking(turn.Basis, SpaceId,
            tree => tree.Adding(new BookmarkState(BookmarkId, ParentId, Title, Url, ShowsInEverySpace), BeforeId));

    #endregion
}
