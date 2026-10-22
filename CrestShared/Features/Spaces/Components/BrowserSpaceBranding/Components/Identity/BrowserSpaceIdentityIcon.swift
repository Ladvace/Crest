import SwiftUI

struct BrowserSpaceIdentityIcon: View {
    let identity: BrowserSpaceIdentity
    var size: CGFloat = 24

    init(space: some BrowserSpaceIdentifying, size: CGFloat = 24) {
        self.init(identity: space.identity, size: size)
    }

    init(identity: BrowserSpaceIdentity, size: CGFloat = 24) {
        self.identity = identity
        self.size = size
    }

    var body: some View {
        Group {
            if let emoji = BrowserIconSymbol.emoji(from: identity.symbol) {
                Text(emoji)
                    .font(.system(size: size * 0.68))
                    .frame(width: size, height: size)
            } else {
                Image(systemName: identity.symbol)
                    .font(.system(size: size * 0.56, weight: .semibold))
                    .foregroundStyle(identity.branding.resolvedSymbolColor.color)
                    .frame(width: size, height: size)
            }
        }
        .accessibilityHidden(true)
    }
}

#if DEBUG
    #Preview("Symbol and locked Space") {
        HStack(spacing: 24) {
            BrowserSpaceIdentityIcon(space: BrowserSpaceBrandingPreviewFixture.simpleSpace, size: 32)
            BrowserSpaceIdentityIcon(space: BrowserSpaceBrandingPreviewFixture.lockedSpace, size: 64)
        }.padding()
    }
#endif
