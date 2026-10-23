import SwiftUI

/// What the editor fills in: a new bookmark or folder, or one being edited,
/// and the Space that keeps it.
struct BrowserBookmarkDraft: Equatable {
    /// The bookmark being edited, or nil for a new one.
    var id: UUID?
    var spaceID: UUID
    var title: String
    /// The address of a link, or nil for a folder.
    var url: String?
    var parentID: UUID?
    var showsInEverySpace: Bool

    var isFolder: Bool { url == nil }
}

/// Names a bookmark or folder, and chooses its address, the folder it sits in
/// and whether every Space shows it.
struct BrowserBookmarkEditor: View {
    @State var draft: BrowserBookmarkDraft
    let library: BrowserBookmarkLibrary
    let save: (BrowserBookmarkDraft) -> Void
    let delete: (() -> Void)?
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            TextField("Name", text: $draft.title)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("bookmark-editor-name")
            if !draft.isFolder {
                TextField("Address", text: Binding(get: { draft.url ?? "" }, set: { draft.url = $0 }))
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("bookmark-editor-address")
            }
            if draft.spaceID == library.spaceID {
                Picker("Folder", selection: $draft.parentID) {
                    Text("Bookmarks").tag(UUID?.none)
                    ForEach(library.folders(excluding: draft.isFolder ? draft.id : nil), id: \.folder.id) { item in
                        Text(String(repeating: "   ", count: item.depth + 1) + item.folder.title)
                            .tag(UUID?.some(item.folder.id))
                    }
                }
            }
            Toggle("Show in all Spaces", isOn: $draft.showsInEverySpace)
            HStack {
                if let delete {
                    Button("Delete", role: .destructive, action: delete)
                }
                Spacer()
                Button("Cancel", action: cancel).keyboardShortcut(.cancelAction)
                Button("Save") { save(draft) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!draft.isFolder && (draft.url ?? "").trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
    }

    private var title: LocalizedStringKey {
        switch (draft.id == nil, draft.isFolder) {
        case (true, true): "New Folder"
        case (true, false): "Bookmark This Page"
        case (false, true): "Edit Folder"
        case (false, false): "Edit Bookmark"
        }
    }
}
