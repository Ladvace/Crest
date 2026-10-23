import SwiftUI

/// The address field's bookmarks button: filled when the page on show is
/// bookmarked, it opens the Space's bookmarks, and a request from the menu or
/// a shortcut opens them too.
struct BrowserBookmarksButton: View {
    let browser: BrowserStore
    let space: SpaceModel
    let page: BrowserBookmarkPage?
    let request: BrowserBookmarksRequest?
    let presentationChanged: (Bool) -> Void

    @State private var isPresented = false
    @State private var bookmarksPage = false

    var body: some View {
        Button {
            open(bookmarkingPage: false)
        } label: {
            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                .font(.system(size: BrowserTabTrailingControlMetrics.pointer.glyphSize, weight: .medium))
                .frame(
                    width: BrowserSiteControlMetrics.triggerSize.width,
                    height: BrowserSiteControlMetrics.triggerSize.height
                )
                .contentShape(.rect)
        }
        .buttonStyle(CrestChromeButtonStyle(controlSize: BrowserSiteControlMetrics.triggerSize))
        .foregroundStyle(isBookmarked ? Color.primary : Color.secondary)
        .popover(isPresented: presentation, arrowEdge: .top) {
            BrowserBookmarksPanel(
                browser: browser, space: space, page: page, startsBookmarkingPage: bookmarksPage,
                dismiss: { presentation.wrappedValue = false }
            )
            .modifier(CrestPopoverStyle())
            .modifier(BrowserDeviceAppearanceEnvironment())
        }
        .onChange(of: request) { _, request in
            if let request { open(bookmarkingPage: request.bookmarksPage) }
        }
        .onChange(of: space.id) {
            if isPresented { presentation.wrappedValue = false }
        }
        .onDisappear {
            if isPresented { presentation.wrappedValue = false }
        }
        .accessibilityLabel(isBookmarked ? "Bookmarks, this page is bookmarked" : "Bookmarks")
        .accessibilityIdentifier("browser-bookmarks")
        .help("Bookmarks (⌥⌘B)")
    }

    private var isBookmarked: Bool {
        BrowserBookmarkLibrary(space: space, spaces: browser.availableSpaces).entry(at: page?.url) != nil
    }

    private var presentation: Binding<Bool> {
        Binding {
            isPresented
        } set: { presented in
            guard presented != isPresented else { return }
            isPresented = presented
            presentationChanged(presented)
        }
    }

    private func open(bookmarkingPage: Bool) {
        bookmarksPage = bookmarkingPage && page != nil
        presentation.wrappedValue = true
    }
}
