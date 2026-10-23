import XCTest

@testable import Crest

@MainActor
final class BrowserBookmarkPathTests: XCTestCase {
    func testAPathAddsItsMissingFoldersAndPutsTheLinkInTheInnermost() throws {
        let store = BrowserStore(seed: .preview)
        let spaceID = store.selectedSpaceID

        let first = try XCTUnwrap(
            store.addBookmark("https://soup.example/", titled: "Soup", in: spaceID, folders: ["Recipes", "Vegan"]))
        let second = try XCTUnwrap(
            store.addBookmark("https://stew.example/", titled: "Stew", in: spaceID, folders: ["recipes", "vegan"]))

        let bookmarks = try XCTUnwrap(store.spaceModel(spaceID)).bookmarks
        let folders = bookmarks.filter(\.isFolder)
        XCTAssertEqual(folders.map(\.title), ["Recipes", "Vegan"])
        let vegan = try XCTUnwrap(folders.first { $0.title == "Vegan" })
        XCTAssertEqual(vegan.parentID, folders.first { $0.title == "Recipes" }?.id)
        XCTAssertEqual(bookmarks.first { $0.id == first }?.parentID, vegan.id)
        XCTAssertEqual(bookmarks.first { $0.id == second }?.parentID, vegan.id)
    }

    /// An address that names its scheme stays as written, a host and port is
    /// on the web, neither is read as a folder, and a folder named with a dot
    /// or a colon isn't read as an address.
    func testAPathReadsEveryKindOfAddressWithoutTurningItIntoFolders() throws {
        let cases: [(String, [String], String?)] = [
            ("recipes/vegan/soup.example", ["recipes", "vegan"], "https://soup.example"),
            ("recipes/vegan/", ["recipes", "vegan"], nil),
            ("work/about:blank", ["work"], "about:blank"),
            ("mailto:team@example.com", [], "mailto:team@example.com"),
            ("file:///Users/me/notes.txt", [], "file:///Users/me/notes.txt"),
            ("data:text/html,<p>hi</p>", [], "data:text/html,<p>hi</p>"),
            ("dev/localhost:3000/app", ["dev"], "https://localhost:3000/app"),
            ("http://example.com/a/b", [], "http://example.com/a/b"),
            ("v1.2/Q3: plans/example.com/docs/v1.2", ["v1.2", "Q3: plans"], "https://example.com/docs/v1.2"),
            ("192.168.1.1:8080", [], "https://192.168.1.1:8080"),
            ("news/xn--80ak6aa92e.xn--p1ai", ["news"], "https://xn--80ak6aa92e.xn--p1ai"),
        ]
        for (text, folders, url) in cases {
            let path = try XCTUnwrap(BrowserBookmarkPath(text), text)
            XCTAssertEqual(path.folders, folders, text)
            XCTAssertEqual(path.url, url, text)
        }
        XCTAssertNil(BrowserBookmarkPath("https://"))

        // A folder already kept stays a folder, though it reads as a site.
        let kept = try XCTUnwrap(BrowserBookmarkPath("dev.to/news.example") { $0.isEmpty && $1 == "dev.to" })
        XCTAssertEqual(kept.folders, ["dev.to"])
        XCTAssertEqual(kept.url, "https://news.example")
    }
}
