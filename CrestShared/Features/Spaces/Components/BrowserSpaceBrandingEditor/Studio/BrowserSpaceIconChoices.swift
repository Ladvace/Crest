import SwiftUI

/// A Space's icon choices: a searchable SF Symbol, or an emoji from the
/// emoji picker. `symbol` holds either, as the Space keeps it.
struct BrowserSpaceIconChoices: View {
    // MARK: - Types

    /// How the two choices sit: one above the other, as rows of a form;
    /// side by side; or side by side where the width allows.
    enum Arrangement {
        case stacked
        case sideBySide
        case adaptive
    }

    // MARK: - Variables

    @Binding var symbol: String
    var arrangement = Arrangement.adaptive

    @State private var choosesEmoji = false

    private var emoji: String? { BrowserIconSymbol.emoji(from: symbol) }

    var body: some View {
        switch arrangement {
        case .stacked:
            symbolPicker
            emojiPicker
        case .sideBySide:
            HStack(spacing: 12) {
                symbolPicker
                emojiPicker
            }
        case .adaptive:
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    symbolPicker.frame(minWidth: 220)
                    emojiPicker.frame(minWidth: 220)
                }
                VStack(alignment: .leading, spacing: 12) {
                    symbolPicker
                    emojiPicker
                }
            }
        }
    }

    // MARK: - Choices

    private var symbolPicker: some View {
        BrowserSystemSymbolPicker(
            selection: Binding(get: { emoji == nil ? symbol : "" }, set: { symbol = $0 }))
    }

    private var emojiPicker: some View {
        BrowserArtworkPickerButton(
            title: "Emoji", detail: emoji == nil ? Text("Choose an emoji") : Text("Change emoji")
        ) {
            choosesEmoji = true
        } artwork: {
            if let emoji {
                Text(emoji)
            } else {
                Image(systemName: "face.smiling")
            }
        }
        .accessibilityLabel("Choose Emoji")
        .accessibilityValue(emoji ?? "")
        .browserIconCustomizationPopover(
            .init(
                isPresented: $choosesEmoji, title: "Space Icon", currentEmoji: emoji,
                setEmoji: { symbol = BrowserIconSymbol.symbol(forEmoji: $0) }))
    }
}
