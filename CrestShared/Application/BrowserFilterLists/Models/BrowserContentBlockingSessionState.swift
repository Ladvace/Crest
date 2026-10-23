import Foundation

/// The content blocking each Space of a workspace chose, and the sites the
/// person leaves alone in every Space.
struct BrowserContentBlockingSessionState: Equatable, Sendable {
    let policiesBySpaceID: [UUID: ContentBlockingPolicy]
    let exemptHosts: [String]

    init(policiesBySpaceID: [UUID: ContentBlockingPolicy], exemptHosts: [String] = []) {
        self.policiesBySpaceID = policiesBySpaceID
        self.exemptHosts = exemptHosts
    }

    /// What each Space of `workspace` in the read model chose, and the sites
    /// its app preferences exempt.
    @MainActor
    init(workspace: WorkspaceModel?) {
        self.init(
            policiesBySpaceID: Dictionary(
                uniqueKeysWithValues: (workspace?.spaces.models ?? []).map { space in
                    (space.id, space.settings.browsingPreferences.contentBlocking)
                }),
            exemptHosts: workspace?.appPreferences?.contentBlockingExemptions ?? [])
    }

    /// The policies some Space blocks with.
    var blockingPolicies: Set<ContentBlockingPolicy> {
        Set(policiesBySpaceID.values.filter(\.blocksContent))
    }
}
