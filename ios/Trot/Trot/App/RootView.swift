import SwiftUI
import SwiftData

struct RootView: View {
    @Query(filter: #Predicate<Dog> { $0.archivedAt == nil })
    private var activeDogs: [Dog]

    @State private var hasContinued = false
    @Environment(\.scenePhase) private var scenePhase

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
        .task {
            _ = await NotificationService.requestPermission()
            await rescheduleNotificationsIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await rescheduleNotificationsIfNeeded() }
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
}
