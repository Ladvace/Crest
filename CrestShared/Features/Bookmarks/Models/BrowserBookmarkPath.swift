import Foundation

/// What a person types to bookmark in one go: folders, then an address, each
/// after a "/", as in `recipes/vegan/https://soup.example` or
/// `recipes/vegan/soup.example`. Without an address it names the folders the
/// page on show goes in, as in `recipes/vegan/`. The address starts at the
/// first segment that names a scheme or a host, as `about:blank`,
/// `localhost:3000` and `soup.example` do, unless it names a folder that is
/// already there; every segment before it is a folder, so `v1.2/` and
/// `Q3: plans/` are folders.
struct BrowserBookmarkPath: Equatable {
    // MARK: - Variables

    /// The folders, outermost first, each to be found by name or made.
    let folders: [String]
    /// The address to bookmark, or nil for the page on show.
    let url: String?
    /// The address as it was typed, empty when the path names none.
    let address: String

    // MARK: - Initializers

    /// The path `text` spells, or nil when it names neither a folder nor an
    /// address Crest opens. `hasFolder` answers whether a folder of a name
    /// already sits inside the folders named before it, so a folder named
    /// like a site stays a folder.
    init?(_ text: String, hasFolder: (_ parents: [String], _ name: String) -> Bool = { _, _ in false }) {
        let spelled = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let segments = spelled.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        var folders: [String] = []
        var addressStart = segments.count
        for (index, segment) in segments.enumerated() {
            let name = segment.trimmingCharacters(in: .whitespaces)
            if !name.isEmpty, hasFolder(folders, name) {
                folders.append(name)
            } else if Self.startsAddress(segment) {
                addressStart = index
                break
            } else if !name.isEmpty {
                folders.append(name)
            }
        }
        self.folders = folders
        address = segments[addressStart...].joined(separator: "/")
        if address.isEmpty {
            url = nil
        } else {
            guard let url = Self.url(spelling: address) else { return nil }
            self.url = url
        }
        guard url != nil || !folders.isEmpty else { return nil }
    }

    // MARK: - Actions - Reading

    /// The address `spelled` names: as written when it names its scheme, as
    /// `about:blank` and `file:///notes.txt` do, or else on the web. A web
    /// address needs a host.
    private static func url(spelling spelled: String) -> String? {
        let candidate = namesScheme(spelled) ? spelled : "https://" + spelled
        guard let url = URL(string: candidate), let scheme = url.scheme?.lowercased() else { return nil }
        if scheme == "http" || scheme == "https" {
            guard let host = url.host(), !host.isEmpty else { return nil }
        }
        return candidate
    }

    /// Whether `segment` opens an address: it names a scheme or a host.
    private static func startsAddress(_ segment: String) -> Bool {
        namesScheme(segment) || namesHost(segment)
    }

    /// Whether `spelled` opens with a scheme, as `mailto:` does, rather than
    /// a host and its port, as `localhost:3000` does, or words and a colon,
    /// as `Q3: plans` does.
    private static func namesScheme(_ spelled: String) -> Bool {
        guard let colon = spelled.firstIndex(of: ":") else { return false }
        let scheme = spelled[..<colon]
        guard let first = scheme.first, first.isLetter,
            scheme.allSatisfy({ $0.isLetter || $0.isNumber || "+-.".contains($0) })
        else { return false }
        let rest = spelled[spelled.index(after: colon)...]
        if rest.first?.isWhitespace == true { return false }
        let port = rest.prefix { $0 != "/" }
        return port.isEmpty || !port.allSatisfy(\.isNumber)
    }

    /// Whether `segment` is a host, with or without its port: `localhost`, an
    /// IP address, or names ending in letters or a punycode ending, as
    /// `soup.example` and `xn--80ak6aa92e.xn--p1ai` do and `v1.2` doesn't.
    private static func namesHost(_ segment: String) -> Bool {
        let parts = segment.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        if parts.count == 2, parts[1].isEmpty || !parts[1].allSatisfy(\.isNumber) { return false }
        let host = parts[0].lowercased()
        if host == "localhost" { return parts.count == 2 || segment == host }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2,
            labels.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" } })
        else { return false }
        if labels.count == 4, labels.allSatisfy({ $0.allSatisfy(\.isNumber) }) { return true }
        let ending = labels[labels.count - 1]
        return ending.count >= 2 && (ending.allSatisfy(\.isLetter) || ending.hasPrefix("xn--"))
    }
}
