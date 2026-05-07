import SwiftUI

/// Strava-style centre action button for the bottom tab bar. The whole point
/// of Trot is "walk your dog" — that primary action gets a permanent home in
/// the centre of the bar, larger than the tab icons, raised slightly above
/// the surface, with the brand coral.
///
/// Tap brings up a small action menu with two options:
///   - Start a walk (opens ExpeditionView in expedition mode)
///   - Log a past walk (opens LogWalkSheet for manual entry)
///
/// Layout: overlay on the TabView in HomeView via `.overlay(alignment: .bottom)`.
/// The button sits roughly over the centre tab item slot (between Journey and
/// Insights with our 4-tab layout), raised above the bar by ~12pt so it reads
/// as a floating primary action.
struct WalkActionFAB: View {
    let onStartWalk: () -> Void
    let onLogPastWalk: () -> Void

    @State private var pressed = false

    var body: some View {
        Menu {
            Button(action: onStartWalk) {
                Label("Start a walk", systemImage: "figure.walk")
            }
            Button(action: onLogPastWalk) {
                Label("Log a past walk", systemImage: "clock.arrow.circlepath")
            }
        } label: {
            ZStack {
                // Soft halo to lift the button off the bar's glass background.
                Circle()
                    .fill(Color.brandPrimary.opacity(0.20))
                    .frame(width: 72, height: 72)
                    .blur(radius: 10)

                Circle()
                    .fill(Color.brandPrimary)
                    .frame(width: 60, height: 60)
                    .shadow(color: Color.brandPrimary.opacity(0.45), radius: 10, x: 0, y: 4)

                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Color.brandTextOnPrimary)
            }
            .scaleEffect(pressed ? 0.92 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !pressed {
                        withAnimation(.brandDefault) { pressed = true }
                    }
                }
                .onEnded { _ in
                    withAnimation(.brandDefault) { pressed = false }
                }
        )
        .accessibilityLabel("Walk with your dog")
        .accessibilityHint("Choose to start a walk or log a past walk.")
    }
}
