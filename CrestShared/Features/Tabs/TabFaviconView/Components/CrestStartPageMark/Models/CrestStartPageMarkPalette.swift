import SwiftUI

struct CrestStartPageMarkPalette {
    let background: Color
    let banner: Color
    /// The bar across the banner's top.
    let bar: Color

    init(colorScheme: ColorScheme) {
        self = colorScheme == .dark ? .dark : .light
    }

    private static let light = CrestStartPageMarkPalette(
        background: Color(red: 0.973, green: 0.969, blue: 0.953),
        banner: Color(red: 0.090, green: 0.133, blue: 0.220),
        bar: Color(red: 1.0, green: 0.706, blue: 0.0)
    )

    private static let dark = CrestStartPageMarkPalette(
        background: Color(red: 0.110, green: 0.145, blue: 0.188),
        banner: Color(red: 0.925, green: 0.914, blue: 0.882),
        bar: Color(red: 1.0, green: 0.706, blue: 0.0)
    )

    private init(background: Color, banner: Color, bar: Color) {
        self.background = background
        self.banner = banner
        self.bar = bar
    }
}
