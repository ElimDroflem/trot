import SwiftUI

@main
struct TrotApp: App {
    @State private var hasContinued = false

    var body: some Scene {
        WindowGroup {
            if hasContinued {
                HomeView()
            } else {
                OnboardingGateView(onContinue: { hasContinued = true })
            }
        }
    }
}
