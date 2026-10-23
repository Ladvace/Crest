namespace CrestCore.Contracts;

/// <summary>
/// A link a Space keeps out of its sidebar, or a folder of them when it has no
/// <see cref="Url"/>. Bookmarks form a forest through <see cref="ParentId"/>, and
/// siblings stand in the order the Space lists them. A bookmark that
/// <see cref="ShowsInEverySpace"/> is listed in every Space's bookmarks, with
/// everything inside it.
/// </summary>
public sealed record BookmarkState(Guid Id, Guid? ParentId, string Title, string? Url, bool ShowsInEverySpace) {
    #region Static Variables

    /// The most bookmarks and folders one Space keeps.
    public const int MaximumCount = 5_000;

    /// The most folders deep a bookmark may sit, counting itself.
    public const int MaximumDepth = FolderState.MaximumDepth;

    /// The longest title a bookmark keeps.
    public const int MaximumTitleLength = 512;

    #endregion

    #region Variables

    /// Whether the bookmark is a folder of others rather than a link.
    [Resolved]
    public bool IsFolder => Url is null;

    #endregion
}
