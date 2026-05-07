import SwiftUI

/// Centre walk button. Sits in the bottom tab bar between the four tab
/// items, treated as the bar's hero action — Strava-style.
///
/// Visual: an iOS-26 Liquid Glass capsule, brand-coral tinted, slightly
/// raised above the tab bar items. The `.glassEffect()` modifier gives us
/// Apple's native blur + light-pass material for free; we tint it coral so
/// it reads as the brand action without looking like a flat sticker.
///
/// Tapping opens a small menu with the same two intents as the old top-right
/// "+" button: Start a walk (live timer) or Log a past walk (manual entry).
struct WalkActionFAB: View {
    let onStartWalk: () -> Void
    let onLogPastWalk: () -> Void

    var body: some View {
        Menu {
            Button(action: onStartWalk) {
                Label("Start a walk", systemImage: "figure.walk")
            }
            Button(action: onLogPastWalk) {
                Label("Log a past walk", systemImage: "clock.arrow.circlepath")
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                Text("Walk")
                    .font(.bodyMedium.weight(.semibold))
            }
            .foregroundStyle(Color.brandTextOnPrimary)
            .frame(width: 96, height: 46)
            // Liquid Glass capsule, coral-tinted, interactive press response.
            // .interactive() gives the press feedback iOS 26 ships with the
            // material so we don't need a custom DragGesture/scaleEffect.
            .glassEffect(
                .regular.tint(Color.brandPrimary).interactive(),
                in: .capsule
            )
        }
        .accessibilityLabel("Walk with your dog")
        .accessibilityHint("Choose to start a walk or log a past walk.")
    }
}
