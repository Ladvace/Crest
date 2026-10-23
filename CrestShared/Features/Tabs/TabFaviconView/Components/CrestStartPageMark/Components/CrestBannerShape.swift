import SwiftUI

/// The banner of CrestArk's mark: a tall tab with a notch cut up into its
/// foot, drawn in the tile's own coordinates, as the app icon draws it.
struct CrestBannerShape: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * x, y: rect.minY + rect.height * y)
        }

        var path = Path()
        path.move(to: point(0.3146, 0.1747))
        path.addLine(to: point(0.6854, 0.1747))
        path.addCurve(to: point(0.7278, 0.2171), control1: point(0.7136, 0.1747), control2: point(0.7278, 0.1888))
        path.addLine(to: point(0.7278, 0.7933))
        path.addCurve(to: point(0.7108, 0.8262), control1: point(0.7278, 0.8075), control2: point(0.7221, 0.8184))
        path.addCurve(to: point(0.6801, 0.8241), control1: point(0.7016, 0.8325), control2: point(0.6914, 0.8318))
        path.addLine(to: point(0.5201, 0.7171))
        path.addCurve(to: point(0.4799, 0.7171), control1: point(0.5067, 0.7079), control2: point(0.4933, 0.7079))
        path.addLine(to: point(0.3199, 0.8241))
        path.addCurve(to: point(0.2892, 0.8262), control1: point(0.3086, 0.8318), control2: point(0.2984, 0.8325))
        path.addCurve(to: point(0.2722, 0.7933), control1: point(0.2779, 0.8184), control2: point(0.2722, 0.8075))
        path.addLine(to: point(0.2722, 0.2171))
        path.addCurve(to: point(0.3146, 0.1747), control1: point(0.2722, 0.1888), control2: point(0.2864, 0.1747))
        path.closeSubpath()
        return path
    }
}
