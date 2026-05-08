import SwiftUI

/// Atmosphere-aware styling. The Trot tabs (Today, Insights, Journey) sit on
/// top of `WeatherMoodLayer`, which paints a sky gradient that varies from
/// bright blue daytime to deep navy night. Two consequences for type and
/// chrome:
///
///   1. Header text rendered *outside* a card swims directly on the
///      atmosphere — `brandSecondary` evergreen on a dark navy gradient
///      becomes nearly invisible. Use `.atmosphereTextPrimary()` /
///      `.atmosphereTextSecondary()` on titles that float above cards so
///      the colour swaps based on `appState.atmosphereIsNight`.
///   2. Cards rendered *on* the atmosphere with the brand cream surface
///      can punch through dark night palettes as flat white blocks. The
///      `brandCardShadow()` modifier now adds a hairline border that ties
///      cards into the surrounding atmosphere — taupe edge on day, pale
///      moonlit edge on night.
///
/// Both helpers read `AppState.atmosphereIsNight` (written by
/// `WeatherMoodLayer` after a snapshot loads). They default to "day" if
/// AppState isn't injected, so previews render sensibly without ceremony.

// MARK: - Atmosphere text modifiers

extension View {
    /// Primary header text floating above the atmosphere. Day = the brand
    /// evergreen `brandSecondary`; night = warm-cream off-white so it stays
    /// legible against deep-navy sky. Use on the page-level title row of
    /// Today / Insights / Journey, never inside a card (cards have white
    /// surface and use `brandTextPrimary` directly).
    func atmosphereTextPrimary() -> some View {
        modifier(AtmosphereForegroundModifier(level: .primary))
    }

    /// Secondary subhead floating above the atmosphere. Day = muted dark
    /// grey; night = a softer warm cream so the subhead still reads but
    /// doesn't compete with the primary title.
    func atmosphereTextSecondary() -> some View {
        modifier(AtmosphereForegroundModifier(level: .secondary))
    }
}

private struct AtmosphereForegroundModifier: ViewModifier {
    enum Level { case primary, secondary }
    let level: Level

    @Environment(AppState.self) private var appState

    func body(content: Content) -> some View {
        content.foregroundStyle(color)
    }

    private var color: Color {
        switch (level, appState.atmosphereIsNight) {
        case (.primary, false):
            return Color.brandSecondary       // evergreen on cream
        case (.primary, true):
            return Color(red: 0.96, green: 0.94, blue: 0.88)   // warm cream on navy
        case (.secondary, false):
            return Color.brandTextSecondary
        case (.secondary, true):
            return Color(red: 0.86, green: 0.84, blue: 0.78).opacity(0.92)
        }
    }
}
