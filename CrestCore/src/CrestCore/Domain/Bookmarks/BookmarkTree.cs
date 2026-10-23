using CrestCore.Contracts;

namespace CrestCore.Domain;

/// A Space's bookmarks as a bounded forest of links and folders, siblings in
/// the order the Space lists them and every folder before what it holds. Each edit answers the bookmarks it leaves,
/// in that order, or refuses with the rule it breaks.
public sealed class BookmarkTree(IReadOnlyList<BookmarkState> bookmarks) {
    #region Variables

    /// Each bookmark by its identity, the first of any that share one.
    private readonly Dictionary<Guid, BookmarkState> byId = Index(bookmarks);

    #endregion

    #region Actions - Reading

    /// The bookmarks `source` makes, keeping their order: a bookmark whose
    /// parent is missing, comes later, is no folder or would sit too deep
    /// moves to the top level, and one that repeats an identity, has a title
    /// past the longest or an address Crest doesn't open, or comes past the
    /// most a Space keeps is left out. Never throws.
    public static IReadOnlyList<BookmarkState> Repaired(IReadOnlyList<BookmarkState> source) {
        ArgumentNullException.ThrowIfNull(source);
        List<BookmarkState> accepted = [];
        Dictionary<Guid, (int Depth, bool IsFolder)> placed = [];
        foreach (var bookmark in source) {
            if (accepted.Count == BookmarkState.MaximumCount) break;
            if (placed.ContainsKey(bookmark.Id) || bookmark.Title.Length > BookmarkState.MaximumTitleLength) continue;
            if (bookmark.Url is { } url && !IsAddress(url)) continue;
            var parent = bookmark.ParentId is { } requested && placed.TryGetValue(requested, out var found) && found.IsFolder
                && found.Depth + 1 < BookmarkState.MaximumDepth ? requested : (Guid?)null;
            accepted.Add(bookmark with { ParentId = parent });
            placed[bookmark.Id] = (parent is { } id ? placed[id].Depth + 1 : 0, bookmark.IsFolder);
        }
        return accepted;
    }

    /// The bookmarks inside `parent`, or at the top level, in order.
    public IEnumerable<BookmarkState> Children(Guid? parent) => bookmarks.Where(bookmark => bookmark.ParentId == parent);

    #endregion

    #region Actions - Editing

    /// The bookmarks with `bookmark` inside its parent, before `beforeId` or
    /// last. Throws `Rejected` when the Space already keeps it or as many as
    /// it may, when its parent is no folder of this Space, or when it would
    /// sit too deep.
    public IReadOnlyList<BookmarkState> Adding(BookmarkState bookmark, Guid? beforeId) {
        ArgumentNullException.ThrowIfNull(bookmark);
        if (byId.ContainsKey(bookmark.Id)) throw new Rejected(new BookmarkAlreadyExists(bookmark.Id));
        if (bookmarks.Count >= BookmarkState.MaximumCount) throw new Rejected(new BookmarkLimitReached(BookmarkState.MaximumCount));
        var added = Checked(bookmark);
        RequirePlacement(added.Id, added.ParentId, beforeId, height: 1);
        return Inserting(bookmarks, added, beforeId);
    }

    /// The bookmarks with `bookmarkId` titled `title`, at `url` when it is a
    /// link, and shown in every Space when `showsInEverySpace`. A folder keeps
    /// no address. Throws `Rejected` when the Space keeps no such bookmark.
    public IReadOnlyList<BookmarkState> Editing(Guid bookmarkId, string title, string? url, bool showsInEverySpace) {
        var held = Held(bookmarkId);
        var edited = Checked(held with {
            Title = title,
            Url = held.IsFolder ? null : url ?? held.Url,
            ShowsInEverySpace = showsInEverySpace
        });
        return [.. bookmarks.Select(bookmark => bookmark.Id == bookmarkId ? edited : bookmark)];
    }

    /// The bookmarks with `bookmarkId`, and everything inside it, inside
    /// `parentId` before `beforeId` or last. Throws `Rejected` when the Space
    /// keeps no such bookmark, when `parentId` is no folder or sits inside the
    /// bookmark, or when the deepest bookmark would sit too deep.
    public IReadOnlyList<BookmarkState> Moving(Guid bookmarkId, Guid? parentId, Guid? beforeId) {
        var held = Held(bookmarkId);
        var subtree = Subtree(bookmarkId);
        if (parentId is { } parent && subtree.Contains(parent)) throw new Rejected(new InvalidBookmarkPlacement());
        if (beforeId is { } before && subtree.Contains(before)) throw new Rejected(new InvalidBookmarkPlacement());
        RequirePlacement(bookmarkId, parentId, beforeId, Height(bookmarkId));
        // The bookmark moves with everything inside it as one block, so a
        // folder always comes before what it holds.
        var block = bookmarks.Where(bookmark => subtree.Contains(bookmark.Id))
            .Select(bookmark => bookmark.Id == bookmarkId ? held with { ParentId = parentId } : bookmark).ToList();
        var result = bookmarks.Where(bookmark => !subtree.Contains(bookmark.Id)).ToList();
        int index = beforeId is { } target ? result.FindIndex(item => item.Id == target) : -1;
        result.InsertRange(index < 0 ? result.Count : index, block);
        return result;
    }

    /// The bookmarks without `bookmarkId` and everything inside it. Throws
    /// `Rejected` when the Space keeps no such bookmark.
    public IReadOnlyList<BookmarkState> Removing(Guid bookmarkId) {
        _ = Held(bookmarkId);
        var subtree = Subtree(bookmarkId);
        return [.. bookmarks.Where(bookmark => !subtree.Contains(bookmark.Id))];
    }

    #endregion

    #region Actions - Rules

    private static Dictionary<Guid, BookmarkState> Index(IReadOnlyList<BookmarkState> bookmarks) {
        ArgumentNullException.ThrowIfNull(bookmarks);
        var index = new Dictionary<Guid, BookmarkState>(bookmarks.Count);
        foreach (var bookmark in bookmarks) index.TryAdd(bookmark.Id, bookmark);
        return index;
    }

    private BookmarkState Held(Guid bookmarkId) =>
        byId.TryGetValue(bookmarkId, out var held) ? held : throw new Rejected(new UnknownBookmark(bookmarkId));

    /// `bookmark` with its title trimmed, or named for its address or as an
    /// untitled folder when blank. Throws `Rejected` for an address Crest
    /// doesn't open.
    private static BookmarkState Checked(BookmarkState bookmark) {
        if (bookmark.Url is { } url && !IsAddress(url)) throw new Rejected(new InvalidBookmarkAddress());
        var title = bookmark.Title.Trim();
        if (title.Length == 0) title = bookmark.Url ?? "Untitled Folder";
        if (title.Length > BookmarkState.MaximumTitleLength) title = title[..BookmarkState.MaximumTitleLength];
        return bookmark with { Title = title };
    }

    private static bool IsAddress(string url) => new WebAddress(url).Normalized is not null;

    /// Throws `Rejected` unless `parentId` is a folder this Space keeps, the
    /// bookmark `height` levels tall fits beneath it, and `beforeId` is a
    /// bookmark among its children.
    private void RequirePlacement(Guid bookmarkId, Guid? parentId, Guid? beforeId, int height) {
        if (parentId is { } parent && (!byId.TryGetValue(parent, out var folder) || !folder.IsFolder || parent == bookmarkId))
            throw new Rejected(new InvalidBookmarkPlacement());
        if (beforeId is { } before && (!byId.TryGetValue(before, out var sibling) || sibling.ParentId != parentId || before == bookmarkId))
            throw new Rejected(new InvalidBookmarkPlacement());
        if ((parentId is { } container ? Depth(container) : 0) + height > BookmarkState.MaximumDepth)
            throw new Rejected(new BookmarkDepthLimitReached(BookmarkState.MaximumDepth));
    }

    /// How many folders deep `bookmarkId` sits, counting itself.
    private int Depth(Guid bookmarkId) {
        int depth = 0;
        for (Guid? id = bookmarkId; id is { } current && byId.TryGetValue(current, out var bookmark); id = bookmark.ParentId) depth++;
        return depth;
    }

    /// How many levels `bookmarkId` and everything inside it span.
    private int Height(Guid bookmarkId) => 1 + Children(bookmarkId).Select(child => Height(child.Id)).DefaultIfEmpty(0).Max();

    private HashSet<Guid> Subtree(Guid bookmarkId) {
        HashSet<Guid> result = [bookmarkId];
        foreach (var child in Children(bookmarkId)) result.UnionWith(Subtree(child.Id));
        return result;
    }

    private static List<BookmarkState> Inserting(IEnumerable<BookmarkState> source, BookmarkState bookmark, Guid? beforeId) {
        var result = source.ToList();
        int index = beforeId is { } before ? result.FindIndex(item => item.Id == before) : -1;
        result.Insert(index < 0 ? result.Count : index, bookmark);
        return result;
    }

    #endregion
}
