import SwiftUI
import SwiftData
import Combine

/// Live-walk sheet — the heart of expedition mode. Replaces "Log a past walk"
/// for new walks. While open, a 1Hz timer drives:
///   - the elapsed-time display
///   - the estimated distance (pace × elapsed)
///   - the live "X metres to ???" countdown to the next landmark
///   - mid-walk landmark celebration toasts when the dog crosses a landmark
///
/// Distance is pace-based estimation (matches the rest of the app's no-GPS
/// stance per spec.md). Wall-clock time means backgrounding doesn't lose
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
            HStack(spacing: Space.sm) {
                Text(formatKm(estimatedKm))
                    .font(.bodyLarge.weight(.semibold))
                    .foregroundStyle(Color.brandPrimary)
                Text("·")
                    .foregroundStyle(Color.brandTextTertiary)
                Text("pace \(String(format: "%.1f", pace))")
                    .font(.bodyMedium)
                    .foregroundStyle(Color.brandTextSecondary)
            }
        }
    }

    @ViewBuilder
    private var landmarkProgress: some View {
        if let next = nextLandmark {
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(Color.brandTextTertiary)
                    Text("\(metersToNext(next))m to ???")
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

        // Mid-walk landmark detection: which landmarks does the live estimated
        // total cross?
        guard let route = JourneyService.currentRoute(for: dog) else { return }
        let live = dog.routeProgressKm + estimatedKm
        for landmark in route.landmarks where landmark.kmFromStart > dog.routeProgressKm {
            if landmark.kmFromStart <= live, !state.firedLandmarkIDs.contains(landmark.id) {
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
            let oldKm = dog.routeProgressKm
            let application = JourneyService.applyWalk(minutes: minutes, to: dog)
            appState.enqueueWalkComplete(
                dogName: dog.name,
                minutes: minutes,
                application: application,
                oldProgressKm: oldKm,
                newProgressKm: application.routeCompleted == nil ? dog.routeProgressKm : route.totalKm,
                routeName: route.name,
                routeTotalKm: route.totalKm
            )
        }
        try? modelContext.save()
        dismiss()
    }

    // MARK: - Helpers

    private var pace: Double {
        JourneyService.paceKmH(for: dog.activityLevel)
    }

    private var estimatedKm: Double {
        state.estimatedKm(pace: pace)
    }

    private var nextLandmark: NextLandmark? {
        // Compute against the LIVE position (logged progress + estimated this session)
        let liveDog = dog
        let snapshotProgress = liveDog.routeProgressKm
        liveDog.routeProgressKm = snapshotProgress + estimatedKm
        let result = JourneyService.nextLandmark(for: liveDog)
        liveDog.routeProgressKm = snapshotProgress
        return result
    }

    private func metersToNext(_ next: NextLandmark) -> Int {
        next.metersAway
    }

    private func landmarkProgressFraction(_ next: NextLandmark) -> Double {
        // Fill the bar based on how close the user is to the next landmark.
        // Anchor at "1 km away" → 0%, "0m" → 100%. Clamp.
        let m = Double(next.metersAway)
        let fraction = max(0, min(1, 1.0 - (m / 1000.0)))
        return fraction
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func formatKm(_ km: Double) -> String {
        if km < 1.0 {
            return "\(Int(round(km * 1000)))m"
        }
        return String(format: "%.2f km", km)
    }
}
