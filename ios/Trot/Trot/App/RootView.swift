import SwiftUI
import SwiftData

struct RootView: View {
    @Query(filter: #Predicate<Dog> { $0.archivedAt == nil })
    private var activeDogs: [Dog]

    @State private var hasContinued = false

    var body: some View {
        if !hasContinued {
            OnboardingGateView(onContinue: { hasContinued = true })
        } else if activeDogs.isEmpty {
            AddDogView()
        } else {
            HomeView()
        }
    }
}
