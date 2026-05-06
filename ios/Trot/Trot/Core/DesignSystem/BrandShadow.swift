import SwiftUI

/// Mirror of `--shadow-card` from `design-reference/Trot Design System/colors_and_type.css`.
/// Two stacked shadows: a tight contact shadow plus a soft ambient one, both in the
/// brand-warm near-black so cards feel grounded against the cream surface without
/// looking like they're floating in space.
///
/// CSS reference:
///     --shadow-card: 0 1px 2px rgba(31,27,22,0.04), 0 4px 16px rgba(31,27,22,0.06);
extension View {
    /// Applies the brand card shadow. Use on every elevated card surface
    /// (`.background(Color.brandSurfaceElevated)` is the usual giveaway).
    func brandCardShadow() -> some View {
        self
            .shadow(color: BrandShadow.warmInk.opacity(0.04), radius: 1, x: 0, y: 1)
            .shadow(color: BrandShadow.warmInk.opacity(0.06), radius: 8, x: 0, y: 4)
    }
}

private enum BrandShadow {
    /// Brand-warm near-black (#1F1B16) — the rgba colour referenced by the CSS shadow tokens.
    static let warmInk = Color(red: 31.0 / 255.0, green: 27.0 / 255.0, blue: 22.0 / 255.0)
}
