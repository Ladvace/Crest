import SwiftUI

/// The bar along the top of a Peek, as Arc and Zen draw theirs: close and the
/// Space it opened from on one side, the page's site in the middle, and on the
/// other side the link and the way to keep the page as a tab in a Space.
struct BrowserPeekHeader: View {
    // MARK: - Static Variables

    static let height: CGFloat = 40
    private static let iconSize: CGFloat = 14

    // MARK: - Variables

    let page: BrowserPage?
    let spaces: [BrowserSpaceIdentity]
    let selectedSpaceID: UUID
    let dismiss: () -> Void
    let openInSpace: (BrowserSpaceRuntimeAssignment) -> Void

    private var selectedSpace: BrowserSpaceIdentity? {
        spaces.first { $0.id == selectedSpaceID }
    }

    var body: some View {
        HStack(spacing: CrestSpacing.small) {
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .contentShape(.rect)
            }
            .buttonStyle(CrestChromeButtonStyle(controlSize: CGSize(width: 26, height: 26)))
            .keyboardShortcut("w", modifiers: .command)
            .accessibilityLabel("Close Peek")
            .accessibilityIdentifier("peek-close-control")
            .help("Close Peek (⌘W)")

            if let selectedSpace {
                HStack(spacing: 5) {
                    BrowserSpaceIdentityIcon(identity: selectedSpace, size: Self.iconSize)
                    Text(selectedSpace.name).lineLimit(1)
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, CrestSpacing.small)
                .frame(height: 22)
                .background { CrestSurfaceLayer(shape: Capsule()) }
                .accessibilityElement(children: .combine)
            }

            Spacer(minLength: CrestSpacing.small)

            if let page {
                BrowserCopyLinkButton(page: page)
            }
            openControl
        }
        .padding(.horizontal, CrestSpacing.small)
        .frame(height: Self.height)
        .overlay {
            // The site sits in the bar's middle, whatever its sides hold.
            Text(verbatim: site)
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 360)
                .allowsHitTesting(false)
        }
        .background { CrestSurfaceLayer(shape: Rectangle()) }
        .overlay(alignment: .bottom) { Divider() }
    }

    /// The page's site, as the address field shows it when at rest.
    private var site: String {
        guard let address = page?.live.url else { return "" }
        guard let host = URL(string: address)?.host(percentEncoded: false) else { return address }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    /// Opens the page in the Space it came from, or, from the menu, another.
    private var openControl: some View {
        HStack(spacing: 0) {
            Button {
                if let selectedSpace { openInSpace(selectedSpace.assignment) }
            } label: {
                HStack(spacing: 4) {
                    Text("Open in")
                        .foregroundStyle(.secondary)
                    Text(selectedSpace?.name ?? String(localized: "Space"))
                        .lineLimit(1)
                }
                .padding(.leading, CrestSpacing.small)
                .padding(.trailing, 6)
                .frame(height: 26)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("o", modifiers: .command)
            .accessibilityIdentifier("peek-open-selected-space")
            .help("Open in \(selectedSpace?.name ?? "Space") (⌘O)")

            Divider().frame(height: 14)

            Menu {
                ForEach(spaces) { candidate in
                    Button {
                        openInSpace(candidate.assignment)
                    } label: {
                        BrowserSpaceIdentityLabel(identity: candidate, title: candidate.name)
                    }
                }
                .crestMenuActionLabelStyle()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .frame(width: 22, height: 26)
                    .contentShape(.rect)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Choose Destination Space")
            .accessibilityIdentifier("peek-space-picker")
            .help("Open in another Space")
        }
        .font(.caption.weight(.semibold))
        .background { CrestSurfaceLayer(shape: Capsule()) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("peek-space-control")
    }
}
