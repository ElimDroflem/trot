import SwiftUI
import SwiftData

struct RootView: View {
    @Query(filter: #Predicate<Dog> { $0.archivedAt == nil })
    private var activeDogs: [Dog]

    @State private var hasContinued = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    /// DEBUG-only — pulled into a computed property so Release just reads
    /// `false` and short-circuits cleanly. The deep-link handler flips this
    /// for simulator testing.
    private var debugGateBypassed: Bool {
        #if DEBUG
        return appState.debugGateBypassed
        #else
        return false
        #endif
    }

    /// True once the user has consented to continue (or DEBUG bypass is set).
    /// Side effects that require having a user — notification permission
    /// requests, milestone celebrations, recap auto-show — gate on this.
    private var isPastGate: Bool {
        hasContinued || debugGateBypassed
    }

    private var recapDog: Dog? {
        guard let id = appState.pendingRecapDogID else { return nil }
        return activeDogs.first(where: { $0.persistentModelID == id })
    }

    var body: some View {
        Group {
            if !hasContinued && !debugGateBypassed {
                OnboardingGateView(onContinue: { hasContinued = true })
            } else if activeDogs.isEmpty {
                AddDogView()
            } else {
                HomeView()
            }
        }
        .overlay {
            // Walk-complete dopamine fires FIRST so the immediate "you just walked"
            // moment lands before any milestone celebration that the same save may
            // have triggered.
            //
            // Both overlays are gated on `isPastGate` defensively so a stale
            // queued celebration (e.g. notification deep link, unusual race)
            // never renders on top of the sign-in screen.
            if isPastGate, let event = appState.pendingWalkComplete {
                WalkCompleteOverlay(
                    event: event,
                    dog: activeDogs.first(where: { $0.persistentModelID == event.dogID })
                ) {
                    withAnimation(.brandDefault) {
                        appState.consumeWalkComplete()
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else if isPastGate, let celebration = appState.pendingCelebration {
                CelebrationOverlay(celebration: celebration) {
                    withAnimation(.brandDefault) {
                        appState.consumeCelebration()
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.brandDefault, value: appState.pendingWalkComplete?.id)
        .animation(.brandDefault, value: appState.pendingCelebration?.id)
        .sheet(item: Binding(
            get: { recapDog.map { RecapDogID(id: $0.persistentModelID) } },
            set: { newValue in
                if newValue == nil {
                    if let dog = recapDog {
                        RecapService.markSeen(for: dog)
                        try? modelContext.save()
                    }
                    appState.pendingRecapDogID = nil
                }
            }
        )) { wrapper in
            if let dog = activeDogs.first(where: { $0.persistentModelID == wrapper.id }) {
                RecapView(recap: RecapService.weekly(for: dog), dog: dog) {
                    RecapService.markSeen(for: dog)
                    try? modelContext.save()
                    appState.pendingRecapDogID = nil
                }
            }
        }
        // Permission requests, milestone celebrations, and recap auto-show all
        // require the user to have crossed the gate. Otherwise the user sees
        // iOS notification dialogs and in-app celebration overlays (e.g.
        // firstWalk from a DebugSeed walk) on top of a sign-in screen they
        // haven't agreed to yet — which is the bug Corey reported.
        //
        // Keyed on `isPastGate` so the side effects run BOTH for users who
        // arrive at Home directly (debugGateBypassed = true on launch) AND for
        // users who tap Continue (hasContinued flips true mid-session).
        .task(id: isPastGate) {
            guard isPastGate else { return }
            // Notification permission ask moved into
            // `OnboardingPermissionsView` so it fires in a clean
            // dedicated context, not on top of milestone celebrations
            // queued by DebugSeed on first paint. Reschedule still runs
            // here — it's a no-op if permission was denied.
            await rescheduleNotificationsIfNeeded()
            checkMilestones()
            checkRecapAutoShow()
            #if DEBUG
            fireDebugCelebrationIfRequested()
            #endif
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, isPastGate {
                Task { await rescheduleNotificationsIfNeeded() }
                checkMilestones()
                checkRecapAutoShow()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .trotRecapTapped)) { _ in
            // User tapped the Sunday recap push. Surface the recap for the currently-
            // selected dog. Auto-show conditions don't apply here — the user explicitly
            // asked for it.
            if let dog = appState.selectedDog(from: activeDogs) {
                appState.pendingRecapDogID = dog.persistentModelID
            }
        }
    }

    private func rescheduleNotificationsIfNeeded() async {
        if let dog = activeDogs.first {
            await NotificationService.reschedule(for: dog)
        } else {
            await NotificationService.cancelAll()
        }
    }

    /// Catches time-based beats (firstWeek) plus any beats that became eligible
    /// while the app was backgrounded. Walk-triggered beats are caught by LogWalkSheet.
    private func checkMilestones() {
        for dog in activeDogs {
            let new = MilestoneService.newMilestones(for: dog)
            guard !new.isEmpty else { continue }
            MilestoneService.markFired(new, on: dog)
            appState.enqueueCelebrations(new, for: dog)
        }
        try? modelContext.save()
    }

    #if DEBUG
    /// Honours `-DebugCelebrationMinutes N [-DebugCelebrationUnlock page1|page2]` —
    /// pushes a synthetic walk-complete event onto AppState so the overlay
    /// renders on first paint. Lets simulator testing QA the overlay
    /// without driving the LogWalkSheet UI.
    private func fireDebugCelebrationIfRequested() {
        guard let minutes = appState.pendingDebugCelebrationMinutes,
              let dog = activeDogs.first else { return }
        let target = max(1, dog.dailyTargetMinutes)
        let half = max(1, target / 2)
        let unlock = appState.pendingDebugCelebrationUnlock
        let oldMinutes: Int
        let newMinutes: Int
        let pagesAlready: Int
        switch unlock {
        case .page1:
            oldMinutes = max(0, half - 5)
            newMinutes = max(half, oldMinutes + minutes)
            pagesAlready = 0
        case .page2:
            oldMinutes = max(0, target - 5)
            newMinutes = max(target, oldMinutes + minutes)
            pagesAlready = 1
        case .none:
            oldMinutes = 0
            newMinutes = minutes
            pagesAlready = 0
        }
        let event = PendingWalkComplete(
            dogID: dog.persistentModelID,
            dogName: dog.name.isEmpty ? "Your dog" : dog.name,
            minutes: minutes,
            isFirstWalk: false,
            oldMinutesToday: oldMinutes,
            newMinutesToday: newMinutes,
            targetMinutes: target,
            pagesAlreadyToday: pagesAlready
        )
        appState.pendingWalkCompletes.append(event)
        appState.pendingDebugCelebrationMinutes = nil
        appState.pendingDebugCelebrationUnlock = .none
    }
    #endif

    /// Auto-presents the weekly recap sheet on Sunday evenings if it hasn't been
    /// seen yet this week. Selected dog only — multi-dog households see one
    /// recap at a time, switching dogs surfaces the next week's worth on next open.
    private func checkRecapAutoShow() {
        guard appState.pendingRecapDogID == nil else { return }
        guard appState.pendingCelebration == nil else { return }  // milestones first
        guard let dog = appState.selectedDog(from: activeDogs) else { return }
        if RecapService.shouldAutoShow(for: dog) {
            appState.pendingRecapDogID = dog.persistentModelID
        }
    }
}

/// Identifiable wrapper so .sheet(item:) can drive on a Dog's persistent ID without
/// needing the Dog itself to be Identifiable in a sheet-friendly way.
private struct RecapDogID: Identifiable, Equatable {
    let id: PersistentIdentifier
}
