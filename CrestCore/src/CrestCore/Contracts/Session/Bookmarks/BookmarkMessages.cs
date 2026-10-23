namespace CrestCore.Contracts;

#region Rejections - Bookmarks

/// The Space already keeps a bookmark with this identity.
public sealed record BookmarkAlreadyExists(Guid BookmarkId) : Rejection;

/// The bookmark, or the deepest one inside it, would sit `Limit` folders deep
/// or deeper.
public sealed record BookmarkDepthLimitReached(int Limit) : Rejection;

/// The Space already keeps `Limit` bookmarks and folders.
public sealed record BookmarkLimitReached(int Limit) : Rejection {
    #region Variables

    /// What the person is told.
    [Localized(Argument = nameof(Limit))]
    public string Message => "A Space keeps up to %lld bookmarks.";

    #endregion
}

/// The bookmark cannot go where the edit places it: what should hold it is no
/// folder, is the bookmark itself or sits inside it, or what it should go
/// before holds another place.
public sealed record InvalidBookmarkPlacement : Rejection;

/// A bookmark's address is no web address Crest opens.
public sealed record InvalidBookmarkAddress : Rejection {
    #region Variables

    /// What the person is told.
    [Localized]
    public string Message => "Enter a web address to bookmark.";

    #endregion
}

/// The Space keeps no bookmark with this identity.
public sealed record UnknownBookmark(Guid BookmarkId) : Rejection;

#endregion
