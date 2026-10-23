using CrestCore.Application;

namespace CrestCore.Contracts;

/// Moves a bookmark, with everything inside it, into the folder `ParentId` or
/// to the top level, before `BeforeId` or last.
public sealed record MoveBookmark(Guid WorkspaceId, Guid SpaceId, Guid BookmarkId, Guid? ParentId, Guid? BeforeId)
    : SessionIntent(WorkspaceId) {
    #region Actions - Session

    internal override SessionEdit? Edit(NativeSessionAuthority workspace, SessionTurn turn) =>
        workspace.Bookmarking(turn.Basis, SpaceId, tree => tree.Moving(BookmarkId, ParentId, BeforeId));

    #endregion
}
