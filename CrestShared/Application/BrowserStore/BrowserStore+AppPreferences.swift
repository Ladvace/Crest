import Foundation

extension BrowserStore {
    /// Sends one app-preference intent. Only the preference record changes, so
    /// every window keeps showing what it showed; a refusal changes nothing.
    @discardableResult
    func sendAppPreferences(_ intent: some Intent) -> Bool {
        family.send(intent, from: self, failure: "Core preference command failed")
    }

    /// Content blocking blocks on the site `host` names, or leaves it and its
    /// subdomains alone, in every Space.
    @discardableResult
    func setContentBlocking(_ blocks: Bool, onSite host: String) -> Bool {
        sendAppPreferences(SetSiteContentBlocking(workspaceID: family.workspaceID, host: host, blocks: blocks))
    }

    /// Whether content blocking leaves `host`, or a site it is a subdomain
    /// of, alone.
    func exemptsFromContentBlocking(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return (workspaceModel?.appPreferences?.contentBlockingExemptions ?? []).contains {
            host == $0 || host.hasSuffix("." + $0)
        }
    }
}
