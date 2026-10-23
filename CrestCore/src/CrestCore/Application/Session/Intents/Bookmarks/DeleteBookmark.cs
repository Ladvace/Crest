using CrestCore.Application;

namespace CrestCore.Contracts;

/// Deletes a bookmark, or a folder with everything inside it.
public sealed record DeleteBookmark(Guid WorkspaceId, Guid SpaceId, Guid BookmarkId) : SessionIntent(WorkspaceId) {
    #region Actions - Session

    internal override SessionEdit? Edit(NativeSessionAuthority workspace, SessionTurn turn) =>
        workspace.Bookmarking(turn.Basis, SpaceId, tree => tree.Removing(BookmarkId));

    #endregion
}
