import SwiftUI
import SwiftData

/// Full-screen post-walk dopamine moment. Fires after EVERY walk save (manual
/// log or expedition mode finish). The visual story:
///   1. Dog photo (or placeholder) inside a coral ring that fills 0→100%.
///   2. Headline — "X minutes with Luna!" in display type.
///   3. Generated dog-voice line in italics ("Sniffed everything past the
///      duck pond!") — fetched from `LLMService` on appear; absent on miss.
///   4. Route progress mini-bar that animates from oldFraction → newFraction.
///   5. Optional landmark stamps if any landmarks were crossed.
///   6. Optional "[Route name] complete" line if a route finished.
///   7. Continue button.
///
/// New brand voice: celebration carve-out applies. Exclamation marks allowed
/// and encouraged; the dopamine comes from the visual progression PLUS the
/// generated dog-voice that names something specific from the walk.
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

    var body: some View {
        ZStack {
            Color.brandSurface.ignoresSafeArea()

            VStack(spacing: Space.lg) {
                Spacer()

                photoWithRing
                    .frame(width: 180, height: 180)

                headline

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
            .offset(y: appeared ? 0 : 16)
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
        } else {
            withAnimation(.brandDefault) { appeared = true }
            withAnimation(.brandCelebration.delay(0.15)) {
                ringFraction = 1
            }
            // Initialise routeFraction at the OLD position so the animate-to-new
            // produces a visible bar advance.
            routeFraction = event.oldFraction
            withAnimation(.brandDefault.delay(0.45)) {
                routeFraction = event.newFraction
            }
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
                Text("+\(formatKm(event.kmAdded)) km")
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
            Text("CROSSED")
                .font(.caption.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(Color.brandTextTertiary)
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

    private func formatKm(_ km: Double) -> String {
        if km < 1.0 {
            return String(format: "%.2f", km)
        }
        return String(format: "%.1f", km)
    }
}

