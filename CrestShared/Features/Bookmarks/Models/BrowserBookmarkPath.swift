import Foundation

/// What a person types to bookmark in one go: folders, then an address, each
/// after a "/", as in `recipes/vegan/https://soup.example` or
/// `recipes/vegan/soup.example`. Without an address it names the folders the
/// page on show goes in, as in `recipes/vegan/`. A segment holding a dot or a
/// scheme starts the address; every segment before it is a folder.
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
    /// address Crest opens.
    init?(_ text: String) {
        let spelled = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let segments = spelled.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        let addressStart =
            segments.firstIndex { $0.contains(".") || $0.hasSuffix(":") || $0.contains("://") } ?? segments.count
        folders = segments[..<addressStart]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        address = segments[addressStart...].joined(separator: "/")
        if address.isEmpty {
            url = nil
        } else {
            let candidate = address.contains("://") ? address : "https://" + address
            guard let host = URL(string: candidate)?.host(), !host.isEmpty else { return nil }
            url = candidate
        }
        guard url != nil || !folders.isEmpty else { return nil }
    }
}
