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

                dot(at: CrestStartPageMarkMetrics.upperDotCenter, side: side, color: palette.upperDot)
                dot(at: CrestStartPageMarkMetrics.lowerDotCenter, side: side, color: palette.lowerDot)
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
    /// One of the mark's dots, at `center` as a fraction of the tile.
    private func dot(at center: CGPoint, side: CGFloat, color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(
                width: side * CrestStartPageMarkMetrics.dotRadiusRatio * 2,
                height: side * CrestStartPageMarkMetrics.dotRadiusRatio * 2
            )
            .position(x: side * center.x, y: side * center.y)
    }
}

#if DEBUG
    #Preview("Component") {
        CrestStartPageMark().frame(width: 80, height: 80).padding()
    }
#endif
