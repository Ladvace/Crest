import SwiftUI

struct CrestStartPageMark: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let palette = CrestStartPageMarkPalette(colorScheme: colorScheme)

            ZStack {
                RoundedRectangle(
                    cornerRadius: side * CrestStartPageMarkMetrics.cornerRadiusRatio,
                    style: .continuous
                )
                .fill(palette.background)

                CrestBannerShape()
                    .fill(palette.banner)

                bar(side: side, color: palette.bar)
            }
            .frame(width: side, height: side)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            .overlay {
                RoundedRectangle(
                    cornerRadius: side * CrestStartPageMarkMetrics.cornerRadiusRatio,
                    style: .continuous
                )
                .strokeBorder(
                    .primary.opacity(CrestStartPageMarkMetrics.borderOpacity),
                    lineWidth: CrestStartPageMarkMetrics.borderWidth
                )
            }
        }
    }
}

extension CrestStartPageMark {
    /// The bar across the banner's top, wider than the banner.
    private func bar(side: CGFloat, color: Color) -> some View {
        let frame = CrestStartPageMarkMetrics.barFrame
        return RoundedRectangle(cornerRadius: side * CrestStartPageMarkMetrics.barCornerRadiusRatio)
            .fill(color)
            .frame(width: side * frame.width, height: side * frame.height)
            .position(x: side * frame.midX, y: side * frame.midY)
    }
}

#if DEBUG
    #Preview("Component") {
        CrestStartPageMark().frame(width: 80, height: 80).padding()
    }
#endif
