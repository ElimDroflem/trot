import SwiftUI
import SwiftData
import Combine

/// Live-walk sheet — the heart of expedition mode. Replaces "Log a past walk"
/// for new walks. While open, a 1Hz timer drives:
///   - the elapsed-time display
///   - the live "X minutes to ???" countdown to the next landmark
///   - mid-walk landmark celebration toasts when the dog crosses a landmark
///
/// Time-based throughout — landmarks unlock by accumulated minutes, not by
/// estimated distance. Wall-clock time means backgrounding doesn't lose
/// progress.
struct ExpeditionView: View {
    let dog: Dog

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var state = ExpeditionState()
    @State private var showingFinishConfirm = false
    @State private var showingDiscardConfirm = false
    @State private var visibleLandmark: Landmark?
    @State private var landmarkVisibleSince: Date?

    /// 1Hz tick — refreshes elapsedSeconds for the UI.
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.brandSurface.ignoresSafeArea()

                VStack(spacing: Space.lg) {
                    photoMarker
                        .padding(.top, Space.lg)

                    timerBlock

                    landmarkProgress

                    Spacer()

                    finishButton
                        .padding(.horizontal, Space.lg)
                        .padding(.bottom, Space.xl)
                }

                if let visibleLandmark {
                    LandmarkRevealView(landmark: visibleLandmark)
                        .padding(.horizontal, Space.md)
                        .padding(.top, Space.sm)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(10)
                }
            }
            .navigationTitle("Walking with \(dog.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showingDiscardConfirm = true }
                        .tint(.brandPrimary)
                }
            }
        }
        .interactiveDismissDisabled(state.elapsedSeconds > 0)
        .onReceive(tick) { _ in
            handleTick()
        }
        .confirmationDialog(
            "End this walk?",
            isPresented: $showingFinishConfirm,
            titleVisibility: .visible
        ) {
            Button("Finish walk") { finishWalk() }
            Button("Keep walking", role: .cancel) {}
        }
        .confirmationDialog(
            "Discard this walk?",
            isPresented: $showingDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep walking", role: .cancel) {}
        } message: {
            Text("The time so far won't be saved.")
        }
    }

    // MARK: - Components

    private var photoMarker: some View {
        ZStack {
            Circle()
                .stroke(Color.brandDivider, lineWidth: 6)
                .frame(width: 160, height: 160)
            Circle()
                .stroke(Color.brandPrimary.opacity(0.6), lineWidth: 6)
                .frame(width: 160, height: 160)
                .scaleEffect(pulseScale)
                .opacity(pulseOpacity)
                .animation(
                    .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                    value: pulseScale
                )

            if let data = dog.photo, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 140, height: 140)
                    .clipShape(Circle())
            } else {
                Image(systemName: "dog.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.brandSecondary.opacity(0.6))
                    .frame(width: 140, height: 140)
                    .background(Color.brandSecondaryTint)
                    .clipShape(Circle())
            }
        }
    }

    /// Computed property used as an animation key so the pulse runs.
    private var pulseScale: CGFloat {
        state.elapsedSeconds % 2 == 0 ? 1.06 : 1.0
    }

    private var pulseOpacity: Double {
        state.elapsedSeconds % 2 == 0 ? 0.4 : 0.7
    }

    private var timerBlock: some View {
        VStack(spacing: Space.xs) {
            Text(formatTime(state.elapsedSeconds))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(Color.brandTextPrimary)
                .monospacedDigit()
            Text("with \(dog.name)")
                .font(.bodyMedium)
                .foregroundStyle(Color.brandTextSecondary)
        }
    }

    @ViewBuilder
    private var landmarkProgress: some View {
        if let next = nextLandmark {
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(Color.brandTextTertiary)
                    Text("\(next.minutesAway) min to ???")
                        .font(.bodyLarge.weight(.semibold))
                        .foregroundStyle(Color.brandTextPrimary)
                    Spacer()
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.brandDivider.opacity(0.6))
                        Capsule()
                            .fill(Color.brandPrimary)
                            .frame(width: geo.size.width * landmarkProgressFraction(next))
                    }
                }
                .frame(height: 8)
            }
            .padding(.horizontal, Space.lg)
        } else {
            Text("Final stretch.")
                .font(.bodyLarge.weight(.semibold))
                .foregroundStyle(Color.brandSecondary)
        }
    }

    private var finishButton: some View {
        Button(action: { showingFinishConfirm = true }) {
            Text("Finish walk")
                .font(.bodyLarge.weight(.semibold))
                .foregroundStyle(Color.brandTextOnPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.md)
                .background(Color.brandPrimary)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .disabled(state.elapsedSeconds < 5)
        .opacity(state.elapsedSeconds < 5 ? 0.5 : 1)
    }

    // MARK: - Tick handler (live progression + mid-walk landmark fires)

    private func handleTick() {
        state.tick()

        // Auto-dismiss landmark toast after ~3s.
        if let since = landmarkVisibleSince, Date.now.timeIntervalSince(since) >= 3 {
            withAnimation(.brandDefault) {
                visibleLandmark = nil
                landmarkVisibleSince = nil
            }
        }

        // Mid-walk landmark detection: live position is the dog's saved
        // progress on the route + the minutes elapsed in this session.
        guard let route = JourneyService.currentRoute(for: dog) else { return }
        let live = dog.routeProgressMinutes + state.elapsedMinutes
        for landmark in route.landmarks where landmark.minutesFromStart > dog.routeProgressMinutes {
            if landmark.minutesFromStart <= live, !state.firedLandmarkIDs.contains(landmark.id) {
                state.markLandmarkFired(landmark.id)
                withAnimation(.brandCelebration) {
                    visibleLandmark = landmark
                    landmarkVisibleSince = .now
                }
                break  // one toast at a time
            }
        }
    }

    // MARK: - Finish

    private func finishWalk() {
        let minutes = max(1, state.elapsedMinutes)
        let walk = Walk(
            startedAt: state.startedAt,
            durationMinutes: minutes,
            distanceMeters: nil,
            source: .manual,
            notes: "",
            dogs: [dog]
        )
        modelContext.insert(walk)
        do {
            try modelContext.save()
        } catch {
            // Save failed — bail without applying journey progress
            dismiss()
            return
        }

        // Notifications + milestones (mirrors the LogWalkSheet save flow)
        Task { await NotificationService.reschedule(for: dog) }
        let new = MilestoneService.newMilestones(for: dog)
        if !new.isEmpty {
            MilestoneService.markFired(new, on: dog)
            appState.enqueueCelebrations(new, for: dog)
        }

        // Journey progression + walk-complete celebration
        if let route = JourneyService.currentRoute(for: dog) {
            let oldMinutes = dog.routeProgressMinutes
            let isFirstWalk = (dog.walks ?? []).count == 1
            let application = JourneyService.applyWalk(minutes: minutes, to: dog)
            if !application.landmarksCrossed.isEmpty {
                MomentDiaryService.recordUnlocks(
                    for: dog,
                    crossings: application.landmarksCrossed,
                    seasonID: route.id,
                    modelContext: modelContext
                )
            }
            appState.enqueueWalkComplete(
                dog: dog,
                minutes: minutes,
                isFirstWalk: isFirstWalk,
                application: application,
                oldProgressMinutes: oldMinutes,
                newProgressMinutes: application.routeCompleted == nil ? dog.routeProgressMinutes : route.totalMinutes,
                routeName: route.name,
                routeTotalMinutes: route.totalMinutes
            )
        }
        try? modelContext.save()
        dismiss()
    }

    // MARK: - Helpers

    private var nextLandmark: NextLandmark? {
        // Compute against the LIVE position (logged progress + minutes elapsed
        // in this session). NEVER mutate `dog` here — it's a @Model reference
        // and mutating from a computed property triggers a render-loop freeze.
        guard let route = JourneyService.currentRoute(for: dog) else { return nil }
        return JourneyService.nextLandmark(
            in: route,
            progressMinutes: dog.routeProgressMinutes + state.elapsedMinutes
        )
    }

    /// Fill the bar based on how close the user is to the next landmark.
    /// Anchor at "30 minutes away" → 0%, "0 min" → 100%. Clamp. 30 minutes is
    /// chosen because the longest gap between landmarks on the bigger routes
    /// is roughly that, so the bar reaches near-empty at the start of a leg.
    private func landmarkProgressFraction(_ next: NextLandmark) -> Double {
        let m = Double(next.minutesAway)
        return max(0, min(1, 1.0 - (m / 30.0)))
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
