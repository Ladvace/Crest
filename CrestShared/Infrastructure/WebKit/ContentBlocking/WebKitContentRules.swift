import Observation
import WebKit

/// The content rules WebKit's binding compiles for every page it builds: each
/// blocking policy's filter lists, less the sites the person exempts, which a
/// Space with that policy applies. Preparations run one after another, and a
/// policy keeps the rules it has until their replacements are compiled, so a
/// page never opens without blocking while a change compiles.
@MainActor
@Observable
final class WebKitContentRules {
    // MARK: - Variables

    /// Why the rules could not be compiled, when they could not.
    private(set) var errorDescription: String?
    /// Advances each time compiled rules are thrown away to be compiled
    /// again, so page owners apply the new ones.
    private(set) var revision = 0
    /// The compiled rules, by the name of the policy they block with, each
    /// with the exempt sites and the generation it was compiled for.
    @ObservationIgnored private var compiled: [String: CompiledRules] = [:]
    /// Advances when the filter lists change, which outdates every policy's
    /// rules.
    @ObservationIgnored private var generation = 0
    /// The preparation under way, which the next one waits for.
    @ObservationIgnored private var preparing: Task<Void, Never>?
    /// The policies Spaces block with, as the last preparation named them,
    /// whose lists the library keeps current.
    @ObservationIgnored private var policiesInUse: Set<ContentBlockingPolicy> = []
    /// What compiles the rules; nil compiles none.
    @ObservationIgnored var provider: (any BrowserContentRuleListProviding)?
    @ObservationIgnored private var filterListUpdates: Task<Void, Never>?

    /// The filter lists the rules are made from, where the provider
    /// downloads any.
    var filterLists: FilterListLibrary? {
        (provider as? BrowserContentRuleListProvider)?.filterLists
    }

    // MARK: - Types

    private struct CompiledRules {
        let lists: [WKContentRuleList]
        let exemptHosts: [String]
        let generation: Int
    }

    // MARK: - Initializers

    init(provider: (any BrowserContentRuleListProviding)?) {
        self.provider = provider
    }

    // MARK: - Actions - Compiling

    /// Compiles the rules of each of `policies` that are missing or outdated,
    /// leaving the sites `exemptHosts` names alone, after any preparation
    /// already under way.
    func prepare(policies: Set<ContentBlockingPolicy>, exemptHosts: [String]) async {
        policiesInUse = policies
        let previous = preparing
        let preparation = Task { [weak self] in
            await previous?.value
            await self?.compile(policies: policies, exemptHosts: exemptHosts)
        }
        preparing = preparation
        await preparation.value
    }

    private func compile(policies: Set<ContentBlockingPolicy>, exemptHosts: [String]) async {
        for policy in policies.sorted(by: { $0.tag < $1.tag }) {
            let generation = generation
            if let current = compiled[policy.name], current.exemptHosts == exemptHosts,
                current.generation == generation
            {
                continue
            }
            guard let provider else {
                compiled[policy.name] = CompiledRules(lists: [], exemptHosts: exemptHosts, generation: generation)
                continue
            }
            do {
                let lists = try await provider.ruleLists(for: policy, exemptHosts: exemptHosts)
                compiled[policy.name] = CompiledRules(lists: lists, exemptHosts: exemptHosts, generation: generation)
                errorDescription = nil
            } catch {
                errorDescription = error.localizedDescription
            }
        }
    }

    /// Checks the filter lists for a newer version whenever a day has
    /// passed, for as long as the rules live, and makes the rules again from
    /// a list that changed.
    func keepFilterListsCurrent() {
        guard filterListUpdates == nil, let filterLists else { return }
        filterLists.listsChanged = { [weak self] in self?.invalidate() }
        filterListUpdates = Task { [weak self, weak filterLists] in
            while !Task.isCancelled, let self, let filterLists {
                await filterLists.refreshIfDue(policies: self.policiesInUse)
                try? await Task.sleep(for: .seconds(60 * 60))
            }
        }
    }

    /// Outdates the compiled rules, which the next preparation compiles
    /// again while pages keep the current ones, and tells page owners to
    /// apply the new ones.
    func invalidate() {
        generation &+= 1
        revision &+= 1
    }

    /// The rules a Space with `policy` applies: the latest compiled, none
    /// before the first.
    func ruleLists(for policy: ContentBlockingPolicy) -> [WKContentRuleList] {
        policy.blocksContent ? compiled[policy.name]?.lists ?? [] : []
    }

}
