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
}
