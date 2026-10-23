import Foundation

/// Chromium Spaces block ads and trackers with uBlock Origin Lite, since
/// Crest's own rules are WebKit's. Crest acts only when a Space's blocking
/// changes: turning it on installs the blocker once, or enables it; turning it
/// off disables the copy Crest installed and leaves one the person installed
/// alone. Between changes the person's own choice stands, and a Space whose
/// blocking didn't change is never opened. A person who removes it keeps it
/// removed.
extension ChromiumExtensionStore {
    // MARK: - Static Variables

    /// uBlock Origin Lite's Chrome Web Store identity.
    static let contentBlockerID = "ddkjiahejlhfcafbddmgiahcphecmpfh"
    private static let contentBlockerName = "uBlock Origin Lite"
    /// The Spaces Crest has installed the blocker in, so it never does again
    /// and knows the copy is its own.
    private static let offeredSpacesKey = "crest.chromium.contentBlocker.offeredSpaces"
    /// Whether each Space blocked when Crest last acted on it, by Space.
    private static let appliedKey = "crest.chromium.contentBlocker.applied"

    // MARK: - Actions - Content blocking

    /// Acts on each Space whose blocking changed since Crest last acted on
    /// it. `blocks` answers for each Space whether it blocks.
    func keepContentBlocker(in spaces: [BrowserSpaceIdentity], blocks: (UUID) -> Bool) async {
        let defaults = UserDefaults.standard
        var offered = Set(defaults.stringArray(forKey: Self.offeredSpacesKey) ?? [])
        var applied = defaults.dictionary(forKey: Self.appliedKey) as? [String: Bool] ?? [:]
        var installs: [UUID] = []
        for space in spaces {
            let key = space.id.uuidString
            let wanted = blocks(space.id)
            guard applied[key] != wanted else { continue }
            applied[key] = wanted
            let installedByCrest = offered.contains(key)
            // Off with no copy of Crest's own leaves the person's choice.
            if !wanted, !installedByCrest { continue }
            await load(space)
            let blocker = installed[space.profileID]?.first { $0.id == Self.contentBlockerID }
            if let blocker {
                if blocker.enabled != wanted {
                    command(wanted ? .enable : .disable, extensionID: blocker.id, space: space)
                }
            } else if wanted, !installedByCrest {
                installs.append(space.id)
                offered.insert(key)
            }
        }
        defaults.set(Array(offered), forKey: Self.offeredSpacesKey)
        defaults.set(applied, forKey: Self.appliedKey)
        guard !installs.isEmpty else { return }
        installImported([
            ImportExtensionInstall(
                extensionID: Self.contentBlockerID, name: Self.contentBlockerName, iconPath: nil, spaceIDs: installs)
        ])
    }
}
