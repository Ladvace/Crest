import SwiftUI

struct BrowserExtensionPinButton: View {
    // MARK: - Static Variables

    private static let size: CGFloat = 18
    private static let glyphSize: CGFloat = 10

    // MARK: - Variables

    let isPinned: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // A pinned extension's pin is white on the accent, which reads on
            // any tile; an unpinned one stays quiet until it's wanted.
            Image(systemName: isPinned ? "pin.fill" : "pin")
                .font(.system(size: Self.glyphSize, weight: .bold))
                .foregroundStyle(isPinned ? AnyShapeStyle(Color.white) : AnyShapeStyle(.secondary))
                .frame(width: Self.size, height: Self.size)
                .background {
                    if isPinned { Circle().fill(.tint) }
                }
        }
        .buttonStyle(
            CrestChromeButtonStyle(
                controlSize: CGSize(width: Self.size, height: Self.size),
                cornerRadius: Self.size / 2,
                showsRestingFill: true
            )
        )
        .accessibilityLabel(isPinned ? "Unpin Extension" : "Pin Extension")
        .help(isPinned ? "Unpin Extension" : "Pin Extension")
    }
}

#if DEBUG
    #Preview("Pin and unpin") {
        @Previewable @State var pinned = false
        BrowserExtensionPinButton(isPinned: pinned, action: { pinned.toggle() }).padding()
    }
#endif
