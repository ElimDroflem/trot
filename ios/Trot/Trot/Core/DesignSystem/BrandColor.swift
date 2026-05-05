import SwiftUI

// Asset-catalog colorsets generate `Color.brandPrimary` etc automatically
// (Xcode 16+ symbol generation). This file only declares the semantic aliases
// from colors_and_type.css that aren't backed by their own colorset.

extension Color {
    static let fg1 = Color.brandTextPrimary
    static let fg2 = Color.brandTextSecondary
    static let fg3 = Color.brandTextTertiary
    static let bg1 = Color.brandSurface
    static let bg2 = Color.brandSurfaceElevated
    static let bg3 = Color.brandSurfaceSunken
}
