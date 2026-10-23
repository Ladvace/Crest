import SwiftUI

/// Copies the page's address from the address field, then shows a check for
/// a moment so the copy reads as done.
struct BrowserCopyLinkButton: View {
    let page: BrowserPage

    @State private var copied = false

    var body: some View {
        Button {
            guard page.copyPageLink() else { return }
            copied = true
        } label: {
            Image(systemName: copied ? "checkmark" : "link")
                .font(.system(size: BrowserTabTrailingControlMetrics.pointer.glyphSize, weight: .medium))
                .contentTransition(.symbolEffect(.replace))
                .frame(
                    width: BrowserSiteControlMetrics.triggerSize.width,
                    height: BrowserSiteControlMetrics.triggerSize.height
                )
                .contentShape(.rect)
        }
        .buttonStyle(CrestChromeButtonStyle(controlSize: BrowserSiteControlMetrics.triggerSize))
        .foregroundStyle(.secondary)
        .accessibilityLabel(copied ? "Link Copied" : "Copy Page Link")
        .accessibilityIdentifier("browser-copy-link")
        .help("Copy Page Link (⇧⌘C)")
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }
}
