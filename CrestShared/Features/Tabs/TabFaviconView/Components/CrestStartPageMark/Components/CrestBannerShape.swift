import SwiftUI

/// The banner of CrestArk's mark: a tall tab with a notch cut up into its
/// foot, drawn in the tile's own coordinates, as the app icon draws it.
struct CrestBannerShape: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }

        var path = Path()
        path.move(to: point(0.3146, 0.1589))
        path.addLine(to: point(0.6854, 0.1589))
        path.addCurve(to: point(0.7278, 0.2013), control1: point(0.7136, 0.1589), control2: point(0.7278, 0.1730))
        path.addLine(to: point(0.7278, 0.7775))
        path.addCurve(to: point(0.7108, 0.8104), control1: point(0.7278, 0.7917), control2: point(0.7221, 0.8026))
        path.addCurve(to: point(0.6801, 0.8083), control1: point(0.7016, 0.8167), control2: point(0.6914, 0.8160))
        path.addLine(to: point(0.5201, 0.6418))
        path.addCurve(to: point(0.4799, 0.6418), control1: point(0.5067, 0.6326), control2: point(0.4933, 0.6326))
        path.addLine(to: point(0.3199, 0.8083))
        path.addCurve(to: point(0.2892, 0.8104), control1: point(0.3086, 0.8160), control2: point(0.2984, 0.8167))
        path.addCurve(to: point(0.2722, 0.7775), control1: point(0.2779, 0.8026), control2: point(0.2722, 0.7917))
        path.addLine(to: point(0.2722, 0.2013))
        path.addCurve(to: point(0.3146, 0.1589), control1: point(0.2722, 0.1730), control2: point(0.2864, 0.1589))
        path.closeSubpath()
        return path
    }
}
