import AppKit

@MainActor
struct BrowserExtensionActionPresentation: Identifiable {
    let id: String
    let displayName: String
    let badgeText: String
    var icon: NSImage?
    let isEnabled: Bool
    let isPinned: Bool
    let isLoading: Bool

    init(
        id: String,
        displayName: String,
        badgeText: String = "",
        icon: NSImage? = nil,
        isEnabled: Bool = true,
        isPinned: Bool = false,
        isLoading: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.badgeText = badgeText
        self.icon = icon
        self.isEnabled = isEnabled
        self.isPinned = isPinned
        self.isLoading = isLoading
    }

}

extension BrowserExtensionActionPresentation {
    /// An action as the engine lists it.
    init(_ action: ExtensionAction) {
        self.init(
            id: action.id, displayName: action.name, badgeText: action.badge,
            icon: action.icon.flatMap(NSImage.init(extensionIcon:)), isEnabled: action.enabled,
            isPinned: action.pinned)
    }
}

extension NSImage {
    /// An extension's icon, which the engine encodes at twice its size in
    /// points. An image without a visible pixel, which the engine sends for
    /// an icon an extension draws at runtime and hasn't drawn yet, is none.
    convenience init?(extensionIcon data: Data) {
        self.init(data: data)
        guard Self.hasVisiblePixel(self) else { return nil }
        size = NSSize(width: size.width / 2, height: size.height / 2)
    }

    /// Whether any pixel of `image` shows at all.
    private static func hasVisiblePixel(_ image: NSImage) -> Bool {
        guard
            let bitmap = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first
                ?? image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:))
        else { return true }
        guard bitmap.hasAlpha else { return true }
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide where (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 1) > 0.02 {
                return true
            }
        }
        return false
    }
}
