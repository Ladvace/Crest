import SwiftUI

struct CrestStartPageMarkPalette {
    let background: Color
    let banner: Color
    /// The dot on the banner.
    let upperDot: Color
    /// The dot in the banner's notch.
    let lowerDot: Color

    init(colorScheme: ColorScheme) {
        self = colorScheme == .dark ? .dark : .light
    }

    private static let light = CrestStartPageMarkPalette(
        background: Color(red: 0.973, green: 0.969, blue: 0.953),
        banner: Color(red: 0.149, green: 0.227, blue: 0.302),
        upperDot: Color(red: 0.953, green: 0.945, blue: 0.922),
        lowerDot: Color(red: 0.149, green: 0.227, blue: 0.302)
    )

    private static let dark = CrestStartPageMarkPalette(
        background: Color(red: 0.110, green: 0.145, blue: 0.188),
        banner: Color(red: 0.925, green: 0.914, blue: 0.882),
        upperDot: Color(red: 0.149, green: 0.227, blue: 0.302),
        lowerDot: Color(red: 0.925, green: 0.914, blue: 0.882)
    )

    private init(background: Color, banner: Color, upperDot: Color, lowerDot: Color) {
        self.background = background
        self.banner = banner
        self.upperDot = upperDot
        self.lowerDot = lowerDot
    }
}
