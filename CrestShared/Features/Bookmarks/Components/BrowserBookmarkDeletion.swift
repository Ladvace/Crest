import SwiftUI

/// A bookmark or folder someone asked to delete, waiting for them to confirm.
/// A folder goes with everything inside it, which the question says.
struct BrowserBookmarkDeletion: Identifiable, Equatable {
    // MARK: - Variables

    let id: UUID
    /// The Space that keeps the bookmark, which the deletion goes to.
    let spaceID: UUID
    let title: String
    let isFolder: Bool

    // MARK: - Initializers

    init(_ entry: BrowserBookmarkLibrary.Entry) {
        id = entry.id
        spaceID = entry.spaceID
        title = entry.bookmark.title
        isFolder = entry.children != nil
    }

    init?(_ draft: BrowserBookmarkDraft) {
        guard let id = draft.id else { return nil }
        self.id = id
        spaceID = draft.spaceID
        title = draft.title
        isFolder = draft.isFolder
    }

    // MARK: - Actions - Presentation

    var question: String {
        isFolder
            ? String(localized: "Delete the folder “\(title)”?")
            : String(localized: "Delete the bookmark “\(title)”?")
    }

    var detail: String? {
        isFolder ? String(localized: "Everything inside it is deleted too.") : nil
    }
}

extension View {
    /// Asks before deleting `pending`, and deletes it once confirmed.
    func bookmarkDeletionConfirmation(
        _ pending: Binding<BrowserBookmarkDeletion?>, delete: @escaping (BrowserBookmarkDeletion) -> Void
    ) -> some View {
        alert(
            pending.wrappedValue?.question ?? "",
            isPresented: Binding(
                get: { pending.wrappedValue != nil },
                set: { if !$0 { pending.wrappedValue = nil } }),
            presenting: pending.wrappedValue
        ) { deletion in
            Button("Delete", role: .destructive) { delete(deletion) }
            Button("Cancel", role: .cancel) {}
        } message: { deletion in
            if let detail = deletion.detail { Text(detail) }
        }
    }
}
