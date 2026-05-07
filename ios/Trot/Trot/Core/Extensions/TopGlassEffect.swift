import SwiftUI

/// iOS-26 system-bar separation. Three layers:
///
///   1. `safeAreaInset(edge: .top)` of zero height with an `.ultraThinMaterial`
///      background — gives the status bar (time/wifi/battery) a permanent
///      translucent backdrop so headlines never read directly through the
///      glyphs even when the screen is unscrolled.
///
///   2. `scrollEdgeEffectStyle(.soft, for: .top)` — the iOS 26 "Liquid Glass"
///      scroll-edge behaviour that strengthens the blur as content scrolls
///      under it. No custom scroll-position math; the system owns it.
///
///   3. `scrollEdgeEffectStyle(.soft, for: .bottom)` — same effect on the
///      bottom edge so content blurs as it scrolls under the tab bar.
///      Without this, content scrolls cleanly behind the bar and labels
///      bleed through.
///
/// Apply to the *root container* of each tab (the ZStack with the mood layer
/// + ScrollView). Single-call wrapper so every tab applies it identically.
extension View {
    /// Adds a translucent glass strip behind the system status bar plus the
    /// iOS-26 soft scroll-edge effect at both top and bottom. Apply at the
    /// root of any scrolling tab.
    func edgeGlass() -> some View {
        self
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear
                    .frame(height: 0)
                    .background(.ultraThinMaterial)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
    }

    /// Old name. Kept as a thin shim until the four tab views are renamed in
    /// the same commit; remove once nothing references it.
    func topStatusGlass() -> some View { edgeGlass() }
}
