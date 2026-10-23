using CrestCore.Application;

namespace CrestCore.Contracts;

/// Gives a bookmark `Title` and, for a link, `Url`, and shows it in every
/// Space or only its own.
public sealed record EditBookmark(Guid WorkspaceId, Guid SpaceId, Guid BookmarkId, string Title, string? Url, bool ShowsInEverySpace)
    : SessionIntent(WorkspaceId) {
    #region Actions - Session

    internal override SessionEdit? Edit(NativeSessionAuthority workspace, SessionTurn turn) =>
        workspace.Bookmarking(turn.Basis, SpaceId, tree => tree.Editing(BookmarkId, Title, Url, ShowsInEverySpace));

    #endregion
}
