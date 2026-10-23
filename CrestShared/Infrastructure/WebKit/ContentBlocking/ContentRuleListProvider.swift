import WebKit

/// Compiles each policy's rules into a WebKit rule-list store: the core
/// translates the policy's downloaded filter lists, or its fallback hosts
/// while none are, and WebKit compiles them once. Rules compiled before from
/// the same lists are looked up rather than made again, and rules no policy
/// uses any longer are removed.
@MainActor
final class BrowserContentRuleListProvider: BrowserContentRuleListProviding {
    // MARK: - Static Variables

    /// What every identifier of Crest's own compiled rules starts with.
    private static let identifierPrefix = "com.pauldavis.crest.content-blocking."

    // MARK: - Variables

    private let core: CrestCore
    private let ruleListStore: WKContentRuleListStore?
    private let compiler: any BrowserContentRuleListCompiling
    let filterLists: FilterListLibrary

    // MARK: - Initializers

    init(
        core: CrestCore,
        ruleListStore: WKContentRuleListStore? = .default(),
        compiler: any BrowserContentRuleListCompiling = BrowserContentRuleListCompilerAdapter(),
        filterLists: FilterListLibrary = FilterListLibrary(directory: nil)
    ) {
        self.core = core
        self.ruleListStore = ruleListStore
        self.compiler = compiler
        self.filterLists = filterLists
    }

    /// The provider a launch uses: an isolated launch compiles into no store
    /// and downloads no lists.
    static func forLaunch(
        core: CrestCore,
        launchEnvironment: BrowserLaunchEnvironment = .current
    ) -> BrowserContentRuleListProvider {
        launchEnvironment.requiresIsolation
            ? BrowserContentRuleListProvider(core: core, ruleListStore: nil)
            : BrowserContentRuleListProvider(
                core: core, filterLists: .forLaunch(launchEnvironment: launchEnvironment))
    }

    // MARK: - Actions - Compiling

    func ruleLists(for policy: ContentBlockingPolicy, exemptHosts: [String]) async throws -> [WKContentRuleList] {
        guard let ruleListStore, policy.blocksContent else { return [] }
        let source = filterLists.source(of: policy, exemptHosts: exemptHosts)
        if let identifiers = filterLists.compiledRules(for: policy, source: source),
            let compiled = await lookUp(identifiers, in: ruleListStore)
        {
            return compiled
        }
        let compiled: (identifiers: [String], lists: [WKContentRuleList])
        do {
            compiled = try await compile(filterLists.listFiles(for: policy), for: policy, exemptHosts: exemptHosts)
        } catch {
            // Lists the core or WebKit refuses leave the policy with its
            // fallback hosts rather than with nothing; a failure of those too
            // reaches the caller and is never remembered.
            compiled = try await compile([], for: policy, exemptHosts: exemptHosts)
        }
        filterLists.remember(compiled.identifiers, for: policy, source: source)
        await removeUnused(from: ruleListStore)
        return compiled.lists
    }

    /// Translates the lists in `files` away from the main actor, then
    /// compiles them.
    private func compile(
        _ files: [URL], for policy: ContentBlockingPolicy, exemptHosts: [String]
    ) async throws -> (identifiers: [String], lists: [WKContentRuleList]) {
        guard let ruleListStore else { return ([], []) }
        let core = core
        let rules = try await Task.detached(priority: .utility) {
            let texts = files.compactMap { try? String(contentsOf: $0, encoding: .utf8) }
            return try core.query(ContentBlockingRules(policy: policy, lists: texts, exemptHosts: exemptHosts))
        }.value
        let identifiers = rules.lists.map(\.identifier)
        let lists = try await compiler.compile(
            identifiers: identifiers, sources: rules.lists.map(\.source), store: ruleListStore)
        return (identifiers, lists)
    }

    private func lookUp(_ identifiers: [String], in store: WKContentRuleListStore) async -> [WKContentRuleList]? {
        var lists: [WKContentRuleList] = []
        for identifier in identifiers {
            guard let list = try? await BrowserContentRuleListCompiler.lookUp(identifier: identifier, store: store)
            else { return nil }
            lists.append(list)
        }
        return lists
    }

    private func removeUnused(from store: WKContentRuleListStore) async {
        let kept = filterLists.compiledIdentifiers
        for identifier in await BrowserContentRuleListCompiler.availableIdentifiers(store: store)
        where identifier.hasPrefix(Self.identifierPrefix) && !kept.contains(identifier) {
            await BrowserContentRuleListCompiler.remove(identifier: identifier, store: store)
        }
    }
}
