import SwiftUI

/// A control's name in a small capsule above it while the pointer is over it,
/// at once rather than after the system tooltip's delay, as Arc names its
/// bottom-bar controls. It takes no clicks and leaves the layout alone.
struct CrestHoverLabel: ViewModifier {
    // MARK: - Static Variables

    /// How far above the control's top the capsule's bottom sits.
    private static let gap: CGFloat = 8

    // MARK: - Variables

    let title: Text
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .onHover { isHovering = $0 }
            .overlay(alignment: .top) {
                // A line along the control's top edge, from which the capsule
                // hangs upward, clear of the control.
                Color.clear
                    .frame(height: 0)
                    .overlay(alignment: .bottom) {
                        if isHovering {
                            CrestHoverLabelCapsule(title: title)
                                .padding(.bottom, Self.gap)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                                .transition(.opacity)
                        }
                    }
            }
            .zIndex(isHovering ? 1 : 0)
    }
}

/// The capsule a hover label shows a control's name in.
struct CrestHoverLabelCapsule: View {
    let title: Text

    var body: some View {
        title
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, CrestSpacing.small)
            .padding(.vertical, CrestSpacing.extraSmall)
            .background { CrestSurfaceLayer(shape: Capsule()) }
    }
}

extension View {
    /// Names the control in a capsule above it while the pointer is over it.
    func crestHoverLabel(_ title: Text) -> some View {
        modifier(CrestHoverLabel(title: title))
    }
}
