import SwiftUI
import SwiftData
import UIKit

/// Full-screen post-walk dopamine moment. Fires after EVERY walk save (manual
/// log or expedition mode finish). The visual story:
///   1. Confetti burst from the centre + success haptic the moment it lands.
///   2. Dog photo zooms up inside a coral ring that fills 0→100%.
///   3. Headline pops in — "X minutes with Luna!" in display type.
///   4. Generated dog-voice line in italics ("Sniffed everything past the
///      duck pond!") — fetched from `LLMService` on appear; absent on miss.
///   5. Route progress mini-bar that animates from oldFraction → newFraction.
///   6. Optional landmark stamps if any landmarks were crossed.
///   7. Optional "[Route name] complete!" line if a route finished.
///   8. Continue button.
///
/// New brand voice: celebration carve-out applies. Loud, share-worthy,
/// exclamation marks. The dopamine comes from staggered springs, haptic
/// feedback, and the dog-voice line naming something specific from the walk.
struct WalkCompleteOverlay: View {
    let event: PendingWalkComplete
    /// Optional — needed for the LLM dog-voice fetch. When nil (rare: dog
    /// archived between enqueue and display), the overlay still renders, just
    /// without the dog-voice line.
    let dog: Dog?
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var ringFraction: Double = 0
    @State private var routeFraction: Double = 0
    @State private var dogVoiceLine: String?
    @State private var photoScale: CGFloat = 0.65
    @State private var headlineScale: CGFloat = 0.85
    @State private var headlineOpacity: Double = 0
    @State private var confettiTrigger = 0

    var body: some View {
        ZStack {
            Color.brandSurface.ignoresSafeArea()

            VStack(spacing: Space.lg) {
                Spacer()

                ZStack {
                    photoWithRing
                        .frame(width: 180, height: 180)
                        .scaleEffect(photoScale)
                    ConfettiBurst(trigger: confettiTrigger)
                        .frame(width: 220, height: 220)
                        .allowsHitTesting(false)
                }

                headline
                    .scaleEffect(headlineScale)
                    .opacity(headlineOpacity)

                if let line = dogVoiceLine {
                    dogVoiceQuote(line)
                        .padding(.horizontal, Space.lg)
                        .transition(.opacity)
                }

                routeBar
                    .padding(.horizontal, Space.lg)

                if !event.landmarksCrossed.isEmpty {
                    landmarkStamps
                        .padding(.horizontal, Space.lg)
                }

                if let routeFinished = event.routeCompleted {
                    routeCompletedLine(routeFinished)
                }

                Spacer()

                Button(action: onDismiss) {
                    Text("Continue")
                        .font(.bodyLarge.weight(.semibold))
                        .foregroundStyle(Color.brandTextOnPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.md)
                        .background(Color.brandPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                }
                .padding(.horizontal, Space.lg)
                .padding(.bottom, Space.xl)
            }
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            runEntranceAnimation()
            fetchDogVoice()
        }
    }

    // MARK: - Entrance animation

    private func runEntranceAnimation() {
        if reduceMotion {
            appeared = true
            ringFraction = 1
            routeFraction = event.newFraction
            photoScale = 1
            headlineScale = 1
            headlineOpacity = 1
            return
        }

        // Success haptic the instant the overlay lands.
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        // Surface fade.
        withAnimation(.brandDefault) { appeared = true }

        // Photo zooms up + ring fills, in sync.
        withAnimation(.brandCelebration.delay(0.05)) {
            photoScale = 1
            ringFraction = 1
        }

        // Confetti at the apex of the photo zoom.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            confettiTrigger += 1
        }

        // Headline pops in just after.
        withAnimation(.brandCelebration.delay(0.25)) {
            headlineScale = 1
            headlineOpacity = 1
        }

        // Initialise routeFraction at the OLD position so the animate-to-new
        // produces a visible bar advance.
        routeFraction = event.oldFraction
        withAnimation(.brandDefault.delay(0.55)) {
            routeFraction = event.newFraction
        }
    }

    // MARK: - LLM dog-voice line

    /// Fire-and-forget LLM fetch. Animates the line in if it returns; silent
    /// on failure. The user never blocks on this — the rest of the overlay
    /// already conveys the win.
    private func fetchDogVoice() {
        guard let dog else { return }
        let event = self.event
        Task {
            let landmarkNames = event.landmarksCrossed.map(\.name)
            let line = await LLMService.walkCompleteLine(
                for: dog,
                minutes: event.minutes,
                isFirstWalk: event.isFirstWalk,
                landmarksHit: landmarkNames,
                routeName: event.routeName,
                nextLandmarkName: event.nextLandmarkName
            )
            await MainActor.run {
                withAnimation(.brandDefault) {
                    dogVoiceLine = line
                }
            }
        }
    }

    // MARK: - Components

    private var photoWithRing: some View {
        ZStack {
            // Track ring (the unfilled portion)
            Circle()
                .stroke(Color.brandDivider, lineWidth: 10)

            // Animated coral arc
            Circle()
                .trim(from: 0, to: ringFraction)
                .stroke(
                    Color.brandPrimary,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Photo / placeholder
            if let data = dog?.photo, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 156, height: 156)
                    .clipShape(Circle())
            } else {
                Image(systemName: "dog.fill")
                    .font(.system(size: 56, weight: .regular))
                    .foregroundStyle(Color.brandSecondary.opacity(0.6))
                    .frame(width: 156, height: 156)
                    .background(Color.brandSecondaryTint)
                    .clipShape(Circle())
            }
        }
    }

    private var headline: some View {
        Text(event.headline)
            .font(.displayMedium)
            .foregroundStyle(Color.brandTextPrimary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Space.lg)
    }

    private func dogVoiceQuote(_ line: String) -> some View {
        Text("\u{201C}\(line)\u{201D}")
            .font(.titleSmall)
            .italic()
            .foregroundStyle(Color.brandSecondary)
            .multilineTextAlignment(.center)
            .accessibilityLabel("\(event.dogName) says: \(line)")
    }

    private var routeBar: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack {
                Text(event.routeName.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(Color.brandTextTertiary)
                Spacer()
                Text("+\(event.minutesAdded) min")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brandPrimary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.brandDivider.opacity(0.6))
                    Capsule()
                        .fill(Color.brandPrimary)
                        .frame(width: geo.size.width * routeFraction)
                }
            }
            .frame(height: 8)
        }
    }

    private var landmarkStamps: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(event.landmarksCrossed.count == 1 ? "MOMENT UNLOCKED" : "MOMENTS UNLOCKED")
                .font(.caption.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(Color.brandPrimary)
            VStack(spacing: Space.xs) {
                ForEach(event.landmarksCrossed) { landmark in
                    HStack(spacing: Space.sm) {
                        Image(systemName: landmark.symbolName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.brandPrimary)
                            .frame(width: 28, height: 28)
                            .background(Color.brandPrimaryTint)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 1) {
                            Text(landmark.name)
                                .font(.bodyMedium.weight(.semibold))
                                .foregroundStyle(Color.brandTextPrimary)
                            if !landmark.description.isEmpty {
                                Text(landmark.description)
                                    .font(.caption)
                                    .foregroundStyle(Color.brandTextSecondary)
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private func routeCompletedLine(_ routeName: String) -> some View {
        HStack(spacing: Space.xs) {
            Image(systemName: "flag.checkered")
                .foregroundStyle(Color.brandSecondary)
            Text("\(routeName) complete!")
                .font(.bodyLarge.weight(.semibold))
                .foregroundStyle(Color.brandSecondary)
        }
    }

}

// MARK: - Confetti

/// Lightweight confetti burst — 18 small coral / secondary dots radiating
/// from the centre, fading and falling slightly. Pure SwiftUI, no library.
/// Re-fires whenever `trigger` changes.
private struct ConfettiBurst: View {
    let trigger: Int

    private let pieceCount = 18

    var body: some View {
        ZStack {
            ForEach(0..<pieceCount, id: \.self) { index in
                ConfettiPiece(
                    seed: index,
                    trigger: trigger
                )
            }
        }
    }
}

private struct ConfettiPiece: View {
    let seed: Int
    let trigger: Int

    @State private var animated = false

    /// Stable per-piece randomness keyed off seed so each piece has a
    /// distinct trajectory but the result is deterministic across renders.
    private var angle: Double {
        Double(seed) * (360.0 / 18.0) + Double(seed % 3) * 7
    }

    private var distance: CGFloat {
        90 + CGFloat(seed % 4) * 14
    }

    private var color: Color {
        seed % 2 == 0 ? Color.brandPrimary : Color.brandSecondary
    }

    private var size: CGFloat {
        seed % 3 == 0 ? 8 : 6
    }

    var body: some View {
        let radians = angle * .pi / 180
        let dx = cos(radians) * distance
        let dy = sin(radians) * distance

        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .offset(
                x: animated ? dx : 0,
                y: animated ? dy + 12 : 0  // slight downward bias as they "fall"
            )
            .scaleEffect(animated ? 0.4 : 1)
            .opacity(animated ? 0 : 1)
            .onChange(of: trigger) { _, _ in
                animated = false
                withAnimation(.easeOut(duration: 0.9)) {
                    animated = true
                }
            }
            .onAppear {
                guard trigger > 0 else { return }
                withAnimation(.easeOut(duration: 0.9)) {
                    animated = true
                }
            }
    }
}
