using CrestCore.Contracts;
using CrestCore.Domain;

namespace CrestCore.Application;

/// Another browser's bookmarks as a reader finds them, from one file or
/// several: folders and links in order, each link kept where it names a web
/// page. They become one Space's bookmarks, in their folders, as many of
/// them as a Space keeps.
internal sealed class BookmarkDraft {
    #region Static Variables

    /// The most links one browser's bookmarks bring.
    public const int MaximumBookmarks = 5_000;

    private const string UntitledFolder = "Untitled Folder";

    #endregion

    #region Types

    private sealed record Folder(Guid Id, string Title, Guid? Parent);

    private sealed record Bookmark(string Title, ImportAddress Address, Guid? Folder, DateTimeOffset AddedAt);

    #endregion

    #region Variables

    /// The folders in the order they were read, each after its parent.
    private readonly List<Folder> folders = [];
    private readonly List<Bookmark> bookmarks = [];
    /// What earlier files brought: the folders a later file's folders join,
    /// by parent and title, and the links, by folder and address, it does not
    /// bring again.
    private readonly Dictionary<(Guid? Parent, string Title), Guid> earlierFolders = [];
    private readonly HashSet<(Guid? Folder, string Address)> earlierBookmarks = [];

    /// Whether reading left out a folder or link Crest would not keep: one
    /// nested too deep or titled too long, or past the folders or links one
    /// Space brings.
    public bool IsCut { get; private set; }

    #endregion

    #region Actions - Reading

    /// Starts reading another of the browser's bookmark files into these
    /// bookmarks: each of its folders joins the folder earlier files brought
    /// with the same title in the same place, and a link such a folder already
    /// holds is not brought again.
    public void BeginFile() {
        foreach (var folder in folders) earlierFolders.TryAdd((folder.Parent, folder.Title), folder.Id);
        foreach (var bookmark in bookmarks) earlierBookmarks.Add((bookmark.Folder, bookmark.Address.Spelling));
    }

    /// Adds a folder `depth` folders deep and answers its identity, or null,
    /// leaving it out with everything in it, when it is past the folders or
    /// nesting a Space keeps or titled longer than a folder keeps.
    public Guid? AppendFolder(string? title, Guid? parent, int depth) {
        string? kept = depth < FolderTree.MaximumDepth ? ImportText.Bounded(title, UntitledFolder, ImportText.MaximumFolderTitle) : null;
        if (kept is not null && earlierFolders.TryGetValue((parent, kept), out var earlier)) return earlier;
        if (kept is null || folders.Count >= FolderTree.MaximumCount) {
            IsCut = true;
            return null;
        }
        var folder = new Folder(Guid.NewGuid(), kept, parent);
        folders.Add(folder);
        return folder.Id;
    }

    /// Adds a link to `url`, unless it names no web page or an earlier file
    /// brought it to the same folder. A link past the links a Space brings,
    /// or titled longer than a tab keeps, is left out.
    public void AppendBookmark(string? title, string url, Guid? folder, DateTimeOffset addedAt) {
        if (ImportAddress.Read(url) is not { } address || earlierBookmarks.Contains((folder, address.Spelling))) return;
        string? kept = ImportText.Bounded(title, address.Host, ImportText.MaximumTitle);
        if (kept is null || bookmarks.Count >= MaximumBookmarks) {
            IsCut = true;
            return;
        }
        bookmarks.Add(new Bookmark(kept, address, folder, addedAt));
    }

    #endregion

    #region Actions - Spaces

    /// The Space the bookmarks make for `source`, named after it, keeping
    /// them as bookmarks in their folders rather than as tabs, every record a
    /// new identity from `ids`: folders first, each after its parent, then
    /// the links, as many as a Space keeps. Null when no link was read. `cut`
    /// says whether a folder or link was left out, here or while reading.
    /// Throws `Rejected` with `BookmarksUnrecognized` for anything else a
    /// Space would not keep.
    public SpaceState? Space(ImportSource source, IIdSource ids, DateTimeOffset now, out bool cut) {
        ArgumentNullException.ThrowIfNull(source);
        ArgumentNullException.ThrowIfNull(ids);
        cut = IsCut;
        if (bookmarks.Count == 0) return null;
        Dictionary<Guid, Guid> folderIds = [];
        List<BookmarkState> read = [];
        foreach (var folder in folders) {
            folderIds[folder.Id] = ids.Next();
            read.Add(new BookmarkState(folderIds[folder.Id], folder.Parent is { } parent ? folderIds.GetValueOrDefault(parent) : null,
                folder.Title, Url: null, ShowsInEverySpace: false));
        }
        foreach (var bookmark in bookmarks)
            read.Add(new BookmarkState(ids.Next(), bookmark.Folder is { } folder ? folderIds.GetValueOrDefault(folder) : null,
                bookmark.Title, bookmark.Address.Spelling, ShowsInEverySpace: false));
        var kept = BookmarkTree.Repaired(read);
        cut = IsCut || kept.Count < read.Count;
        var space = new BrowserDataSpace(source.Title, source.Symbol, source.Accent, Branding: null, Folders: [], Tabs: [], Splits: [],
            ArchivedTabs: [], History: [], StoredSessionCodec.DefaultBrowsingPreferences, SelectedTabId: null);
        try {
            return space.Materialize(ids, now) with { Bookmarks = kept };
        } catch (Rejected rejected) when (rejected.Rejection is ArchiveInvalid) {
            throw new Rejected(new BookmarksUnrecognized());
        }
    }

    #endregion
}
