import SwiftUI

extension Font {
    static let displayLarge = brandDisplay(size: 48, weight: .bold, relativeTo: .largeTitle)
    static let displayMedium = brandDisplay(size: 32, weight: .bold, relativeTo: .title)

    static let titleLarge = Font.system(size: 28, weight: .bold, design: .default)
    static let titleMedium = Font.system(size: 22, weight: .semibold, design: .default)
    static let titleSmall = Font.system(size: 17, weight: .semibold, design: .default)

    static let bodyLarge = Font.system(size: 17, weight: .regular, design: .default)
    static let bodyMedium = Font.system(size: 15, weight: .regular, design: .default)
    static let caption = Font.system(size: 13, weight: .regular, design: .default)
    static let captionBold = Font.system(size: 13, weight: .semibold, design: .default)

    private static func brandDisplay(size: CGFloat, weight: Font.Weight, relativeTo style: Font.TextStyle) -> Font {
        Font.custom("Bricolage Grotesque", size: size, relativeTo: style).weight(weight)
    }
}
