using System.Text.Json.Nodes;

using CrestCore.Application;
using CrestCore.Contracts;

using Xunit;

namespace CrestCore.Tests;

/// A Space keeps bookmarks out of its sidebar, in folders, saves them with
/// itself and carries them in its synced record.
public sealed partial class BrowserContractsTests {
    [Fact]
    public void ASpaceKeepsBookmarksInFoldersThatMoveAndDeleteWhole() {
        var session = SavedSession().Document["session"]!;
        using var device = new TestDevice(session);
        var space = device.Authority.Current.Spaces[0].Id;
        var (recipes, soups, pasta, link) = (Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid(), Guid.NewGuid());
        IReadOnlyList<BookmarkState> Bookmarks() => device.Authority.Current.Spaces[0].Bookmarks;

        device.Send(new AddBookmark(device.Workspace, space, recipes, null, null, "Recipes", null, ShowsInEverySpace: true));
        device.Send(new AddBookmark(device.Workspace, space, soups, recipes, null, "  ", null, false));
        device.Send(new AddBookmark(device.Workspace, space, pasta, soups, null, "", "https://pasta.example/", false));
        device.Send(new AddBookmark(device.Workspace, space, link, null, recipes, "Inspiration", "https://inspiration.example/", false));
        Assert.Equal([(link, (Guid?)null), (recipes, null), (soups, recipes), (pasta, soups)],
            Bookmarks().Select(bookmark => (bookmark.Id, bookmark.ParentId)));
        Assert.Equal(("Untitled Folder", "https://pasta.example/"), (Bookmarks()[2].Title, Bookmarks()[3].Title));
        Assert.True(Bookmarks()[1].ShowsInEverySpace);

        // A folder can't go inside itself, a link holds nothing, and an
        // address Crest doesn't open isn't bookmarked.
        Assert.IsType<InvalidBookmarkPlacement>(Assert.Throws<Rejected>(() =>
            device.Send(new MoveBookmark(device.Workspace, space, recipes, soups, null))).Rejection);
        Assert.IsType<InvalidBookmarkPlacement>(Assert.Throws<Rejected>(() =>
            device.Send(new AddBookmark(device.Workspace, space, Guid.NewGuid(), link, null, "Inside", "https://a.example/", false))).Rejection);
        Assert.IsType<InvalidBookmarkAddress>(Assert.Throws<Rejected>(() =>
            device.Send(new EditBookmark(device.Workspace, space, link, "Inspiration", "file:///etc/hosts", false))).Rejection);

        device.Send(new MoveBookmark(device.Workspace, space, soups, null, link));
        Assert.Equal([(soups, (Guid?)null), (pasta, soups), (link, null), (recipes, null)],
            Bookmarks().Select(bookmark => (bookmark.Id, bookmark.ParentId)));
        device.Send(new DeleteBookmark(device.Workspace, space, soups));
        Assert.Equal([link, recipes], Bookmarks().Select(bookmark => bookmark.Id));

        // The bookmarks are saved with the Space and read back as they were.
        var stored = StoredSessionCodec.DecodeSpace(StoredSessionCodec.Encode(device.Authority.Current.Spaces[0]));
        Assert.Equal(Bookmarks(), stored.Bookmarks);
    }

    [Fact]
    public void ABookmarkIsSuggestedAsThePersonTypesAndUnderItsScope() {
        var (session, space) = PaletteSession([]);
        using var device = new TestDevice(session);
        var window = device.Open(space);
        device.Send(new AddBookmark(device.Workspace, space, Guid.NewGuid(), null, null, "Lentil soup", "https://soup.example/lentil",
            false));

        var typed = device.Query(Asking(window, "lentil")).Groups.SelectMany(group => group.Rows);
        Assert.Contains(typed, row => row.Kind == PaletteRowKind.Bookmark && row.Address == "https://soup.example/lentil");
        var scoped = device.Query(Asking(window, "soup") with { Scope = PaletteScope.Bookmarks }).Groups.SelectMany(group => group.Rows);
        Assert.Equal([PaletteRowKind.Bookmark], scoped.Select(row => row.Kind).Distinct());
    }

    [Fact]
    public void ASpaceAnImportJoinsKeepsItsBookmarksAndTakesTheImportedOnesAfterThem() {
        var fixture = SavedSession();
        var session = fixture.Document["session"]!.AsObject();
        session.Remove("disposableSeedMarker");
        using var device = new TestDevice(session);
        var window = device.Showing(session);
        var kept = Guid.NewGuid();
        device.Send(new AddBookmark(device.Workspace, fixture.Space, kept, null, null, "Kept", "https://kept.example/", false));
        var joining = ImportedSpace("reading", ImportedTab("https://open.example/"));
        joining["bookmarks"] = new JsonArray(StoredSessionCodec.Encode(new BookmarkState(Fixed(401), null, "Recipes", null, false)),
            StoredSessionCodec.Encode(new BookmarkState(Fixed(402), Fixed(401), "Soup", "https://soup.example/", false)));
        Reviewing(device, joining);
        device.Send(new BeginImportCommit());

        device.Send(new ImportReviewedSpaces(device.Workspace, window));

        var joined = device.Authority.Current.Spaces.Single(space => space.Id == fixture.Space);
        Assert.Equal([("Kept", "https://kept.example/"), ("Recipes", null), ("Soup", "https://soup.example/")],
            joined.Bookmarks.Select(bookmark => (bookmark.Title, bookmark.Url)));
    }

    [Fact]
    public void BookmarksTravelWithTheSpaceRecord() {
        var session = OneSpaceSession();
        var folder = StoredSessionCodec.Encode(new BookmarkState(Fixed(301), null, "Recipes", null, true));
        var soup = StoredSessionCodec.Encode(new BookmarkState(Fixed(302), Fixed(301), "Soup", "https://soup.example/", false));
        FirstSpace(session)["bookmarks"] = new JsonArray(folder, soup);
        var journal = new JournalUnderTest(Fixed(212));

        journal.Stage(session);

        var local = session.DeepClone().AsObject();
        FirstSpace(local).Remove("bookmarks");
        var materialized = StoredSessionCodec.DecodeSpace(FirstSpace(journal.Materialize(local))).Bookmarks;
        Assert.Equal([new BookmarkState(Fixed(301), null, "Recipes", null, true),
            new BookmarkState(Fixed(302), Fixed(301), "Soup", "https://soup.example/", false)], materialized);
    }
}
