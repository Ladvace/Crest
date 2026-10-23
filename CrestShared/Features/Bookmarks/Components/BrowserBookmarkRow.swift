import SwiftUI

/// What a row in the library can ask for.
struct BrowserBookmarkRowActions {
    /// Opens a link, in a new tab when the flag says so.
    let open: (BrowserBookmarkLibrary.Entry, Bool) -> Void
    let edit: (BrowserBookmarkLibrary.Entry) -> Void
    let toggleShared: (BrowserBookmarkLibrary.Entry) -> Void
    let delete: (BrowserBookmarkLibrary.Entry) -> Void
}

/// One bookmark in the library: a link that opens its page, or a folder that
/// discloses what it holds. Its menu opens, edits, shares or deletes it.
struct BrowserBookmarkRow: View {
    let entry: BrowserBookmarkLibrary.Entry
    let actions: BrowserBookmarkRowActions

    @State private var isExpanded = false
    @State private var isHovering = false

    var body: some View {
        if let children = entry.children {
            DisclosureGroup(isExpanded: $isExpanded) {
                ForEach(children) { child in
                    BrowserBookmarkRow(entry: child, actions: actions)
                }
            } label: {
                label(symbol: "folder")
                    .contentShape(.rect)
                    .onTapGesture { isExpanded.toggle() }
            }
        } else {
            Button {
                actions.open(entry, false)
            } label: {
                label(symbol: "globe")
            }
            .buttonStyle(.plain)
            .help(entry.bookmark.url ?? "")
        }
    }

    private func label(symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(entry.bookmark.title)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            if entry.bookmark.showsInEverySpace {
                Image(systemName: "square.on.square")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("Shown in all Spaces")
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .crestInteractiveSurface(isSelected: false, isHovering: isHovering, cornerRadius: 6)
        .onHover { isHovering = $0 }
        .contextMenu { menu }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(entry.bookmark.title))
    }

    @ViewBuilder private var menu: some View {
        if entry.children == nil {
            Button("Open") { actions.open(entry, false) }
            Button("Open in New Tab") { actions.open(entry, true) }
            Divider()
        }
        Button(entry.children == nil ? "Edit Bookmark…" : "Edit Folder…") { actions.edit(entry) }
        Button(entry.bookmark.showsInEverySpace ? "Show Only in This Space" : "Show in All Spaces") {
            actions.toggleShared(entry)
        }
        Divider()
        Button("Delete", role: .destructive) { actions.delete(entry) }
    }
}
