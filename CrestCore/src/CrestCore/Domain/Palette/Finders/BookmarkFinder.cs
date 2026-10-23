using CrestCore.Contracts;

namespace CrestCore.Domain;

/// The Space's bookmarked links that match, and those other Spaces show in
/// every Space, ranked by how well they match and how often their page was
/// visited.
internal sealed class BookmarkFinder : PaletteFinder {
    #region Variables

    protected override IReadOnlyList<PaletteSignal> Signals => [PaletteSignal.Learned, PaletteSignal.Usage, PaletteSignal.Match];

    #endregion

    #region Actions - Finding

    internal override IEnumerable<PaletteCandidate> Find(PaletteContext context, PaletteSource source, PaletteQuery query,
        PaletteSuggestions question, bool narrowed) {
        if (context.Space is not { } space) yield break;
        var shared = context.Spaces.Where(other => other.Id != space.Id).SelectMany(Shared);
        foreach (var bookmark in space.Bookmarks.Where(bookmark => !bookmark.IsFolder).Concat(shared)) {
            var url = bookmark.Url!;
            var row = PaletteRow.Of(PaletteRowKind.Bookmark, bookmark.Title, url, subject: bookmark.Id, address: url);
            if (context.Evidence(query, row, bookmark.Title, url) is not { } evidence) continue;
            yield return Scored(context, source, row, evidence, PaletteMemory.Place(url), Matching(evidence));
        }
    }

    /// The links `space` shows in every Space: those marked so, and those
    /// inside a folder marked so.
    private static IEnumerable<BookmarkState> Shared(SpaceState space) {
        var byId = space.Bookmarks.ToDictionary(bookmark => bookmark.Id);
        bool IsShared(BookmarkState bookmark) {
            for (BookmarkState? current = bookmark; current is not null;
                current = current.ParentId is { } parent ? byId.GetValueOrDefault(parent) : null)
                if (current.ShowsInEverySpace) return true;
            return false;
        }
        return space.Bookmarks.Where(bookmark => !bookmark.IsFolder && IsShared(bookmark));
    }

    #endregion
}
