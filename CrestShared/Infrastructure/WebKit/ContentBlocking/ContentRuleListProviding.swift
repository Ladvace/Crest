import WebKit

@MainActor
protocol BrowserContentRuleListProviding: AnyObject {
    /// The compiled rules `policy` blocks with, leaving the sites
    /// `exemptHosts` names alone.
    func ruleLists(for policy: ContentBlockingPolicy, exemptHosts: [String]) async throws -> [WKContentRuleList]
}
