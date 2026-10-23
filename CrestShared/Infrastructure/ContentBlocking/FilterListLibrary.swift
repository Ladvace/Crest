import CryptoKit
import Foundation
import Observation

/// The community filter lists content blocking uses, downloaded from their
/// maintainers and kept in Application Support. Crest ships none of them. A
/// list is downloaded again once a day at most, and only when its maintainers
/// changed it.
@MainActor
@Observable
final class FilterListLibrary {
    // MARK: - Types

    /// What the library remembers beside the lists: when it last checked
    /// them, how the servers named each version, and which compiled rule
    /// lists each policy's lists made.
    private struct Record: Codable {
        /// When every list in use was last checked without a failure.
        var checked: Date?
        /// When each list was last checked without a failure, by its name.
        var listChecked: [String: Date]? = [:]
        var versions: [String: String] = [:]
        var compiled: [String: CompiledRules] = [:]
    }

    /// The compiled rule lists one policy's lists made, and what they were
    /// made from.
    struct CompiledRules: Codable, Equatable {
        let source: String
        let identifiers: [String]
    }

    // MARK: - Static Variables

    /// How long the lists go without being checked for a newer version.
    static let refreshInterval: TimeInterval = 24 * 60 * 60
    /// The largest list the library keeps.
    private static let maximumListByteCount = 24 * 1024 * 1024

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.timeoutIntervalForResource = 60
        return URLSession(configuration: configuration)
    }()

    // MARK: - Variables

    /// When the lists were last checked, if ever.
    var lastChecked: Date? { record.checked }
    /// Whether a check is under way.
    private(set) var isUpdating = false
    /// Why the last check failed, when it did.
    private(set) var failureDescription: String?
    /// Called on the main actor once a list changed, so the rules are made
    /// again.
    @ObservationIgnored var listsChanged: () -> Void = {}

    @ObservationIgnored private let directory: URL?
    private var record: Record

    // MARK: - Initializers

    /// A library kept in `directory`, or one that keeps and downloads
    /// nothing when it is nil.
    init(directory: URL?) {
        self.directory = directory
        record =
            directory.flatMap { try? Data(contentsOf: $0.appendingPathComponent("library.json")) }
            .flatMap { try? JSONDecoder().decode(Record.self, from: $0) } ?? Record()
    }

    /// The library a launch uses: an isolated launch keeps none.
    static func forLaunch(launchEnvironment: BrowserLaunchEnvironment = .current) -> FilterListLibrary {
        guard !launchEnvironment.requiresIsolation,
            let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first
        else { return FilterListLibrary(directory: nil) }
        return FilterListLibrary(
            directory:
                applicationSupport
                .appendingPathComponent(ProductIdentity.storageDirectoryName, isDirectory: true)
                .appendingPathComponent("FilterLists", isDirectory: true))
    }

    // MARK: - Actions - Reading

    /// The file of each list `policy` blocks with that is downloaded.
    func listFiles(for policy: ContentBlockingPolicy) -> [URL] {
        guard let directory else { return [] }
        return lists(of: policy).map { file(of: $0, in: directory) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// What `policy`'s downloaded lists are, as their versions spell them,
    /// with the release that translated them, so rules are made again once a
    /// list changes or a release translates them differently.
    func source(of policy: ContentBlockingPolicy, exemptHosts: [String]) -> String {
        let info = Bundle.main.infoDictionary
        let release =
            "release=\(info?["CFBundleShortVersionString"] as? String ?? "")+\(info?["CFBundleVersion"] as? String ?? "")"
        return ([release] + lists(of: policy).map { "\($0.name)=\(record.versions[$0.name] ?? "")" } + exemptHosts)
            .joined(separator: "\n")
    }

    /// The rule lists compiled for `policy` from `source`, when they were.
    func compiledRules(for policy: ContentBlockingPolicy, source: String) -> [String]? {
        record.compiled[policy.name].flatMap { $0.source == source ? $0.identifiers : nil }
    }

    /// Remembers the rule lists compiled for `policy` from `source`.
    func remember(_ identifiers: [String], for policy: ContentBlockingPolicy, source: String) {
        record.compiled[policy.name] = CompiledRules(source: source, identifiers: identifiers)
        save()
    }

    /// Every compiled rule list some policy still uses.
    var compiledIdentifiers: Set<String> {
        Set(record.compiled.values.flatMap(\.identifiers))
    }

    // MARK: - Actions - Updating

    /// Checks the lists `policies` block with for a newer version, each one
    /// whose last check is a day old, or all of them whenever `force` asks.
    /// A list that fails is tried again on the next check without holding
    /// the others back.
    func refreshIfDue(policies: Set<ContentBlockingPolicy>, force: Bool = false, now: Date = .now) async {
        guard let directory, !isUpdating else { return }
        let inUse = FilterList.all.filter { list in policies.contains { lists(of: $0).contains(list) } }
        let due = inUse.filter { list in
            force || (record.listChecked?[list.name]).map { now.timeIntervalSince($0) >= Self.refreshInterval } ?? true
        }
        guard !due.isEmpty else { return }
        isUpdating = true
        defer { isUpdating = false }
        var changed = false
        var failure: String?
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for list in due {
            do {
                if try await download(list, into: directory) { changed = true }
                record.listChecked = (record.listChecked ?? [:]).merging([list.name: now]) { _, new in new }
            } catch {
                failure = error.localizedDescription
            }
        }
        failureDescription = failure
        if failure == nil { record.checked = now }
        save()
        if changed { listsChanged() }
    }

    /// Downloads `list` when the server has a version the library doesn't,
    /// and answers whether it did.
    private func download(_ list: FilterList, into directory: URL) async throws -> Bool {
        guard let address = URL(string: list.address) else { return false }
        var request = URLRequest(url: address)
        let hasFile = FileManager.default.fileExists(atPath: file(of: list, in: directory).path)
        let kept = hasFile ? record.versions[list.name] : nil
        // Only a server's own tag can be asked about; a digest is compared.
        if let kept, kept.hasPrefix("\"") || kept.hasPrefix("W/") {
            request.setValue(kept, forHTTPHeaderField: "If-None-Match")
        }
        let (data, response) = try await Self.session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if response.statusCode == 304 { return false }
        guard response.statusCode == 200, data.count <= Self.maximumListByteCount,
            let text = String(data: data, encoding: .utf8), Self.isFilterList(text)
        else { throw URLError(.cannotParseResponse) }
        let version =
            response.value(forHTTPHeaderField: "ETag")
            ?? SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard version != kept else { return false }
        try data.write(to: file(of: list, in: directory), options: .atomic)
        record.versions[list.name] = version
        return true
    }

    // MARK: - Actions - Storage

    private func lists(of policy: ContentBlockingPolicy) -> [FilterList] {
        policy.filterListNames.compactMap(FilterList.named)
    }

    private func file(of list: FilterList, in directory: URL) -> URL {
        directory.appendingPathComponent("\(list.name).txt")
    }

    private func save() {
        guard let directory, let data = try? JSONEncoder().encode(record) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: directory.appendingPathComponent("library.json"), options: .atomic)
    }

    /// Whether `text` reads as an Adblock Plus list rather than, say, a
    /// captive portal's page.
    private static func isFilterList(_ text: String) -> Bool {
        let head = text.prefix(512)
        return head.hasPrefix("[Adblock") || head.hasPrefix("!") || head.contains("! Title:")
    }
}
