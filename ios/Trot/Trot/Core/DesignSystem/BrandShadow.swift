import SwiftUI

/// Mirror of `--shadow-card` from `design-reference/Trot Design System/colors_and_type.css`.
/// Two stacked shadows: a tight contact shadow plus a soft ambient one, both in the
/// brand-warm near-black so cards feel grounded against the cream surface without
/// looking like they're floating in space.
///
/// CSS reference:
///     --shadow-card: 0 1px 2px rgba(31,27,22,0.04), 0 4px 16px rgba(31,27,22,0.06);
///
/// Plus a hairline border that ties the card into the surrounding atmosphere.
/// Without it, cards on a deep-navy night sky punch out as flat white blocks
/// (the user feedback was "0% opacity / clunky"). The border swaps:
///   - day  → warm taupe at low alpha (blends into cream)
///   - night → pale moonlit white at low alpha (catches the night palette)
///
/// Atmosphere state is read from `AppState.atmosphereIsNight`, written by
/// `WeatherMoodLayer` after a snapshot loads. Defaults to day.
extension View {
    /// Applies the brand card shadow + a 1px hairline border that tracks the
    /// atmosphere. Use on every elevated card surface
    /// (`.background(Color.brandSurfaceElevated)` is the usual giveaway).
    /// Assumes the card uses `Radius.lg` for its corner radius — every
    /// brand-shaped card does.
    func brandCardShadow() -> some View {
        modifier(BrandCardShadowModifier())
    }
}

private struct BrandCardShadowModifier: ViewModifier {
    @Environment(AppState.self) private var appState

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .strokeBorder(borderColor, lineWidth: 0.75)
            )
            .shadow(color: BrandShadow.warmInk.opacity(0.04), radius: 1, x: 0, y: 1)
            .shadow(color: BrandShadow.warmInk.opacity(0.06), radius: 8, x: 0, y: 4)
    }

    private var borderColor: Color {
        appState.atmosphereIsNight
            ? Color.white.opacity(0.18)
            : Color.brandDivider.opacity(0.55)
    }
}

private enum BrandShadow {
    /// Brand-warm near-black (#1F1B16) — the rgba colour referenced by the CSS shadow tokens.
    static let warmInk = Color(red: 31.0 / 255.0, green: 27.0 / 255.0, blue: 22.0 / 255.0)
}
