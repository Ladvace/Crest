import Foundation

/// What changed in content blocking since a page owner last applied it: the
/// Spaces whose policy changed and the sites whose exemption did.
struct BrowserContentBlockingUpdate {
    let state: BrowserContentBlockingSessionState
    private let changedSpaceIDs: Set<UUID>
    private let changedHosts: Set<String>

    init(
        state: BrowserContentBlockingSessionState,
        previousState: BrowserContentBlockingSessionState?
    ) {
        self.state = state
        changedSpaceIDs = Set(
            state.policiesBySpaceID.compactMap { spaceID, policy in
                guard let previous = previousState?.policiesBySpaceID[spaceID], previous != policy else {
                    return nil
                }
                return spaceID
            }
        )
        changedHosts =
            previousState.map { Set(state.exemptHosts).symmetricDifference($0.exemptHosts) } ?? []
    }

    func policy(for spaceID: UUID) -> ContentBlockingPolicy {
        state.policiesBySpaceID[spaceID] ?? .off
    }

    /// When a page takes its new rules: at once when the person changed its
    /// Space's protection or exempted its site, while it is presented, and on
    /// its next navigation otherwise.
    func activation(for spaceID: UUID, host: String?, isPresented: Bool) -> BrowserContentRuleListActivation {
        guard isPresented else { return .onNextNavigation }
        return changedSpaceIDs.contains(spaceID) || host.map(isChanged) == true ? .immediately : .onNextNavigation
    }

    /// Whether the exemption of `host`, or of a site it is a subdomain of,
    /// changed.
    private func isChanged(_ host: String) -> Bool {
        let host = host.lowercased()
        return changedHosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }
}
