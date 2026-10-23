import Foundation
import WebKit

/// Keeps the Spaces an import brought signed in: the core says which Spaces
/// each site goes to, from its profile and host alone, and each cookie is set
/// in that Space's own website data. A cookie the Space already keeps under
/// the same name, domain and path stays as it is, so an import never signs a
/// Space out of an account it already uses.
@MainActor
enum BrowserSignInImportCommitter {
    // MARK: - Actions - Seeding

    /// Lays `signIns` down, before the review is imported, in the profile of
    /// each Space that comes in new and brings them, through `seeder`, an
    /// engine whose profiles open only once the Space is imported. A Space
    /// that joins one Crest already has takes none this way: its profile is
    /// already open.
    @discardableResult
    static func seed(
        _ signIns: [BrowserImportedSignIn], schema: BrowserCookieStoreSchema, review: SetupImportReview,
        browser: BrowserStore, seeder: any BrowserImportedSignInSeeding
    ) -> Int {
        guard !signIns.isEmpty else { return 0 }
        let (sites, siteIndex) = sites(of: signIns)
        guard
            let routes = try? browser.core.query(
                ImportSignInSources(workspaceID: browser.family.workspaceID, sites: sites))
        else { return 0 }
        let newProfiles = Dictionary(
            review.spaces.filter { $0.included && $0.destinationID == nil }.map { ($0.source.id, $0.source.profileID) },
            uniquingKeysWith: { first, _ in first })
        var byProfile: [UUID: [BrowserImportedSignIn]] = [:]
        for signIn in signIns {
            guard let index = siteIndex[signIn.siteKey], index < routes.routes.count else { continue }
            for spaceID in routes.routes[index].spaceIDs {
                if let profileID = newProfiles[spaceID] { byProfile[profileID, default: []].append(signIn) }
            }
        }
        return byProfile.reduce(0) { written, entry in
            written + seeder.seed(entry.value, schema: schema, intoProfile: entry.key)
        }
    }

    // MARK: - Actions - Importing

    /// Writes `signIns` for the review setup holds over `browser`'s
    /// workspace, answering how many cookies the Spaces took.
    @discardableResult
    static func commit(_ signIns: [BrowserImportedSignIn], browser: BrowserStore) async -> Int {
        guard !signIns.isEmpty else { return 0 }
        let (sites, siteIndex) = sites(of: signIns)
        guard
            let routes = try? browser.core.query(
                ImportSignInDestinations(workspaceID: browser.family.workspaceID, sites: sites))
        else { return 0 }

        var bySpace: [UUID: [BrowserImportedSignIn]] = [:]
        for signIn in signIns {
            guard let index = siteIndex[signIn.siteKey], index < routes.routes.count else { continue }
            for spaceID in routes.routes[index].spaceIDs { bySpace[spaceID, default: []].append(signIn) }
        }

        var written = 0
        for (spaceID, signIns) in bySpace {
            guard let space = browser.spaceModel(spaceID) else { continue }
            let store = BrowserWebsiteDataStore.persistent(for: BrowsingProfile(id: space.profileID)).httpCookieStore
            let existing = await store.allCookies()
            for signIn in signIns where !existing.contains(where: signIn.matches) {
                guard let cookie = signIn.cookie else { continue }
                await store.setCookie(cookie)
                written += 1
            }
        }
        return written
    }

    // MARK: - Actions - Sites

    /// Each site `signIns` belong with, once, and where each sits in that
    /// list by its profile and host.
    private static func sites(of signIns: [BrowserImportedSignIn]) -> ([ImportPasswordSource], [String: Int]) {
        var sites: [ImportPasswordSource] = []
        var siteIndex: [String: Int] = [:]
        for signIn in signIns where siteIndex[signIn.siteKey] == nil {
            siteIndex[signIn.siteKey] = sites.count
            sites.append(signIn.routingSource)
        }
        return (sites, siteIndex)
    }
}
