using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

public sealed partial class NativeSessionAuthority {
    #region Actions - Bookmarks

    /// `basis` with the bookmarks `edit` leaves the Space `spaceId` keeping.
    internal SessionEdit Bookmarking(SessionState basis, Guid spaceId, Func<BookmarkTree, IReadOnlyList<BookmarkState>> edit) {
        var space = Editable(basis, spaceId);
        return new(Replacing(basis, space with { Bookmarks = edit(new BookmarkTree(space.Bookmarks)) }), SyncStaging.Edit);
    }

    #endregion
}
