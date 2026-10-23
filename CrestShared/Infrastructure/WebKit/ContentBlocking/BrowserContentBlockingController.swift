import Observation
import WebKit

/// One page owner's view of WebKit's built-in content blocking: the rules
/// WebKit's binding compiled for every page it builds, and which Spaces and
/// sites of the owner's workspace changed their protection since the owner
/// last applied it.
@MainActor
@Observable
final class BrowserContentBlockingController {
    // MARK: - Variables

    @ObservationIgnored private let rules: WebKitContentRules
    @ObservationIgnored private var reconciledState: BrowserContentBlockingSessionState?

    /// Why the rules could not be compiled, when they could not.
    var errorDescription: String? { rules.errorDescription }
    /// Advances each time the compiled rules change, such as when the filter
    /// lists update.
    var revision: Int { rules.revision }

    // MARK: - Initializers

    /// A view of `rules`, or of no rules where no WebKit binding compiles any.
    init(rules: WebKitContentRules?) {
        self.rules = rules ?? WebKitContentRules(provider: nil)
    }

    // MARK: - Actions - Rules

    /// Compiles the rules every Space of `workspace` blocks with.
    func prepare(in workspace: WorkspaceModel?) async {
        let state = BrowserContentBlockingSessionState(workspace: workspace)
        await rules.prepare(policies: state.blockingPolicies, exemptHosts: state.exemptHosts)
    }

    func invalidateRuleLists() {
        rules.invalidate()
    }

    /// Prepares the rule lists any Space of `workspace` needs, and answers
    /// what changed since the last reconciliation.
    func reconcile(in workspace: WorkspaceModel?) async -> BrowserContentBlockingUpdate {
        let state = BrowserContentBlockingSessionState(workspace: workspace)
        await rules.prepare(policies: state.blockingPolicies, exemptHosts: state.exemptHosts)
        let update = BrowserContentBlockingUpdate(state: state, previousState: reconciledState)
        reconciledState = state
        return update
    }

    func ruleLists(for policy: ContentBlockingPolicy) -> [WKContentRuleList] {
        rules.ruleLists(for: policy)
    }
}
