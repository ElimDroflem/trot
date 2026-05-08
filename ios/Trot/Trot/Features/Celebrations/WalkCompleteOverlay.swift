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
///   5. Story progress bar — minutes-today out of daily target with notches
///      at half and full target. Animates from old → new minutes.
///   6. PAGE 1 / PAGE 2 UNLOCKED stamp when this walk crossed a milestone.
///   7. Caption: "X min to today's first/second page" or "Two pages today,
///      back tomorrow."
///   8. Continue button.
///
/// New brand voice: celebration carve-out applies. Loud, share-worthy,
/// exclamation marks. The dopamine comes from staggered springs, haptic
/// feedback, and the dog-voice line naming something specific from the walk.
///
/// Replaced May 2026 — earlier shape rendered a route progress bar +
/// landmark stamps from the now-removed Journey-mode progression.
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
    @State private var storyFraction: Double = 0
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

                storyProgressBar
                    .padding(.horizontal, Space.lg)

                if event.crossedHalfTarget || event.crossedFullTarget {
                    pageUnlockStamp
                        .padding(.horizontal, Space.lg)
                }

                Text(event.progressCaption)
                    .font(.bodyMedium)
                    .foregroundStyle(Color.brandTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.lg)
                    .padding(.top, 2)

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
            storyFraction = event.newFraction
            photoScale = 1
            headlineScale = 1
            headlineOpacity = 1
            return
        }

        // Layered haptic — a heavy impact lands the moment of arrival, then a
        // success chord at the photo apex. iOS notification haptics on their
        // own read soft; pairing them with an impact makes the celebration
        // feel physical.
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()

        // Surface fade.
        withAnimation(.brandDefault) { appeared = true }

        // Photo zooms up + ring fills, in sync. Tightened slightly (0.05s
        // earlier kick-off, ring uses .brandCelebration so it pops with the
        // photo) so the first second of the overlay is visually dense.
        withAnimation(.brandCelebration) {
            photoScale = 1
            ringFraction = 1
        }

        // Success haptic + confetti at the apex of the photo zoom.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            confettiTrigger += 1
        }

        // Headline pops in just after.
        withAnimation(.brandCelebration.delay(0.22)) {
            headlineScale = 1
            headlineOpacity = 1
        }

        // Story progress bar advance — initialise at the OLD position so
        // the animate-to-new produces a visible advance.
        storyFraction = event.oldFraction
        withAnimation(.brandDefault.delay(0.5)) {
            storyFraction = event.newFraction
        }
    }

    // MARK: - LLM dog-voice line

    /// Fire-and-forget LLM fetch. Animates the line in if it returns; silent
    /// on failure. The user never blocks on this — the rest of the overlay
    /// already conveys the win.
    private func fetchDogVoice() {
        guard let dog else { return }
        let event = self.event
        let unlocked: String? =
            event.crossedFullTarget ? "page 2"
            : event.crossedHalfTarget ? "page 1"
            : nil
        Task {
            let line = await LLMService.walkCompleteLine(
                for: dog,
                minutes: event.minutes,
                isFirstWalk: event.isFirstWalk,
                pageUnlocked: unlocked
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

    /// Story-mode progress bar. Width = today's minutes / daily target,
    /// with the half-target line marked at 50% and the full-target line
    /// at 100%. Animates from `oldFraction` → `newFraction` so the user
    /// sees the bar advance with this walk. Notches sit ON the bar so
    /// the milestone positions are unambiguous.
    private var storyProgressBar: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack {
                Text("MINUTES TODAY")
                    .font(.caption.weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(Color.brandTextTertiary)
                Spacer()
                Text("\(event.newMinutesToday) / \(event.targetMinutes) min")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brandPrimary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.brandDivider.opacity(0.6))
                    // Fill (animates with `storyFraction`)
                    Capsule()
                        .fill(Color.brandPrimary)
                        .frame(width: geo.size.width * storyFraction)
                    // Half-target tick — vertical line at the midpoint
                    Rectangle()
                        .fill(Color.brandTextTertiary.opacity(0.6))
                        .frame(width: 1.5, height: 14)
                        .offset(x: geo.size.width * 0.5 - 0.75, y: -3)
                    // Full-target tick at the right edge — sits at 100%
                    // exactly so it visually "caps" the bar.
                    Rectangle()
                        .fill(Color.brandTextTertiary.opacity(0.6))
                        .frame(width: 1.5, height: 14)
                        .offset(x: geo.size.width - 1.5, y: -3)
                }
            }
            .frame(height: 8)
        }
    }

    /// PAGE 1 / PAGE 2 UNLOCKED stamp. Renders only when this walk
    /// crossed a milestone (`crossedHalfTarget` or `crossedFullTarget`).
    /// Same visual rhythm as the old landmark stamp it replaces — typewriter
    /// caps, tinted accent fill — so the celebration's "you got something"
    /// energy is preserved.
    private var pageUnlockStamp: some View {
        let label = event.crossedFullTarget ? "PAGE 2 UNLOCKED" : "PAGE 1 UNLOCKED"
        return HStack(spacing: Space.sm) {
            Image(systemName: "book.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.brandPrimary)
                .frame(width: 28, height: 28)
                .background(Color.brandPrimaryTint)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(Color.brandPrimary)
                Text("Open the Story tab to read it.")
                    .font(.caption)
                    .foregroundStyle(Color.brandTextSecondary)
            }
            Spacer()
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
