import SwiftUI

/// What a row in the library can ask for.
struct BrowserBookmarkRowActions {
    /// Opens a link, in a new tab when the flag says so.
    let open: (BrowserBookmarkLibrary.Entry, Bool) -> Void
    let edit: (BrowserBookmarkLibrary.Entry) -> Void
    let toggleShared: (BrowserBookmarkLibrary.Entry) -> Void
    let delete: (BrowserBookmarkLibrary.Entry) -> Void
    /// Starts a new link, or a new folder when the flag says so, inside a
    /// folder.
    let addInside: (BrowserBookmarkLibrary.Entry, Bool) -> Void
}

/// Which folders the library shows open, and the bookmark it points out
/// after it was saved.
struct BrowserBookmarkRowDisclosure {
    var expanded: Binding<Set<UUID>>
    var highlighted: UUID?
}

/// One bookmark in the library: a link that opens its page, or a folder that
/// discloses what it holds. Its menu opens, edits, shares or deletes it, and
/// a folder's adds a link or folder inside it.
struct BrowserBookmarkRow: View {
    let entry: BrowserBookmarkLibrary.Entry
    let actions: BrowserBookmarkRowActions
    let disclosure: BrowserBookmarkRowDisclosure

    @State private var isHovering = false

    private var isExpanded: Binding<Bool> {
        Binding(
            get: { disclosure.expanded.wrappedValue.contains(entry.id) },
            set: { open in
                if open {
                    disclosure.expanded.wrappedValue.insert(entry.id)
                } else {
                    disclosure.expanded.wrappedValue.remove(entry.id)
                }
            })
    }

    var body: some View {
        if let children = entry.children {
            DisclosureGroup(isExpanded: isExpanded) {
                ForEach(children) { child in
                    BrowserBookmarkRow(entry: child, actions: actions, disclosure: disclosure)
                }
                if children.isEmpty {
                    Button {
                        actions.addInside(entry, false)
                    } label: {
                        Label("Add a bookmark here", systemImage: "plus")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 3)
                            .padding(.horizontal, 6)
                    }
                    .buttonStyle(.plain)
                }
            } label: {
                label(symbol: isExpanded.wrappedValue ? "folder.fill" : "folder")
                    .contentShape(.rect)
                    .onTapGesture { isExpanded.wrappedValue.toggle() }
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
            if entry.children != nil, isHovering {
                Button {
                    actions.addInside(entry, false)
                } label: {
                    Image(systemName: "plus").font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .help("Add Bookmark Here")
            }
            if entry.bookmark.showsInEverySpace {
                Image(systemName: "square.on.square")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("Shown in all Spaces")
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .crestInteractiveSurface(
            isSelected: disclosure.highlighted == entry.id, isHovering: isHovering, cornerRadius: 6
        )
        .id(entry.id)
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
        } else {
            Button("Add Bookmark Here…") { actions.addInside(entry, false) }
            Button("New Folder Here…") { actions.addInside(entry, true) }
            Divider()
        }
        Button(entry.children == nil ? "Edit Bookmark…" : "Edit Folder…") { actions.edit(entry) }
        Button(entry.bookmark.showsInEverySpace ? "Show Only in This Space" : "Show in All Spaces") {
            actions.toggleShared(entry)
        }
        Divider()
        Button("Delete…", role: .destructive) { actions.delete(entry) }
    }
}
