import CoreGraphics

/// Keeps resize updates local until the interaction commits.
struct BrowserSidebarWidthTransaction: Equatable {
    private(set) var width: CGFloat
    private(set) var persistedWidth: CGFloat
    /// Whether the sidebar may narrow to a column of tab icons.
    let allowsIconColumn: Bool

    init(persistedWidth: CGFloat, allowsIconColumn: Bool = false) {
        self.allowsIconColumn = allowsIconColumn
        let width = BrowserChromeLayout.clampedSidebarWidth(persistedWidth, allowsIconColumn: allowsIconColumn)
        self.width = width
        self.persistedWidth = width
    }

    mutating func resize(to proposedWidth: CGFloat) {
        width = BrowserChromeLayout.clampedSidebarWidth(proposedWidth, allowsIconColumn: allowsIconColumn)
    }

    mutating func commit() -> CGFloat? {
        guard width != persistedWidth else { return nil }
        persistedWidth = width
        return width
    }

    mutating func restore(persistedWidth: CGFloat) {
        let width = BrowserChromeLayout.clampedSidebarWidth(persistedWidth, allowsIconColumn: allowsIconColumn)
        self.width = width
        self.persistedWidth = width
    }
}
