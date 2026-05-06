import SwiftUI
import SwiftData

struct RootView: View {
    @Query(filter: #Predicate<Dog> { $0.archivedAt == nil })
    private var activeDogs: [Dog]

    @State private var hasContinued = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if !hasContinued {
                OnboardingGateView(onContinue: { hasContinued = true })
            } else if activeDogs.isEmpty {
                AddDogView()
            } else {
                HomeView()
            }
        }
        .overlay {
            if let celebration = appState.pendingCelebration {
                CelebrationOverlay(celebration: celebration) {
                    withAnimation(.brandDefault) {
                        appState.consumeCelebration()
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.brandDefault, value: appState.pendingCelebration?.id)
        .task {
            _ = await NotificationService.requestPermission()
            await rescheduleNotificationsIfNeeded()
            checkMilestones()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await rescheduleNotificationsIfNeeded() }
                checkMilestones()
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
}
