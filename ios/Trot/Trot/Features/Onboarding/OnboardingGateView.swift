import SwiftUI
import SwiftData

struct OnboardingGateView: View {
    var onContinue: () -> Void
    /// DEBUG hook: lets `RootView` keep its `@State onboardingDone`
    /// in sync when the wipe button resets the persisted flag. Default
    /// is a no-op so the Preview and the production gate don't need
    /// to wire it.
    var onDebugWipe: () -> Void = {}

    #if DEBUG
    @Environment(\.modelContext) private var modelContext
    @State private var showResetConfirmation = false
    #endif

    var body: some View {
        ZStack {
            Color.brandSurface.ignoresSafeArea()

            VStack(spacing: Space.xl) {
                Spacer()

                TrotLogo(size: 72)

                VStack(spacing: Space.md) {
                    Text("Daily walks for your dog.")
                        .font(.displayMedium)
                        .foregroundStyle(Color.brandTextPrimary)
                        .multilineTextAlignment(.center)

                    Text("Trot detects walks automatically and tailors targets to your dog's breed, age, and health.")
                        .font(.bodyLarge)
                        .foregroundStyle(Color.brandTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Space.lg)
                }

                Spacer()

                VStack(spacing: Space.md) {
                    signInWithAppleButton

                    Text("Sign-in turns on once the Apple Developer account is in place.")
                        .font(.caption)
                        .foregroundStyle(Color.brandTextTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Space.md)

                    Button(action: onContinue) {
                        Text("Continue without sign-in")
                            .font(.bodyLarge.weight(.semibold))
                            .foregroundStyle(Color.brandPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Space.md)
                    }

                    #if DEBUG
                    Button("Reset all data (DEBUG)") {
                        showResetConfirmation = true
                    }
                    .font(.caption)
                    .foregroundStyle(Color.brandTextTertiary)
                    .padding(.top, Space.xs)
                    .confirmationDialog(
                        "Wipe all dogs and walks?",
                        isPresented: $showResetConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Wipe and continue", role: .destructive) {
                            wipeAllData()
                            onDebugWipe()
                            onContinue()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Clears the SwiftData store and resets onboarding so you can run the new-user flow end-to-end. DEBUG only.")
                    }
                    #endif
                }
                .padding(.horizontal, Space.lg)
                .padding(.bottom, Space.xl)
            }
        }
    }

    #if DEBUG
    private func wipeAllData() {
        do {
            try modelContext.delete(model: Walk.self)
            try modelContext.delete(model: WalkWindow.self)
            try modelContext.delete(model: Dog.self)
            try modelContext.save()
        } catch {
            print("Wipe failed: \(error)")
        }
        // Reset onboarding so the next launch goes through the new
        // OnboardingFlowView. Without this, the user lands on the
        // legacy AddDogView fallback which doesn't take them through
        // genre/scene/prologue — a regression for testing the new
        // flow end-to-end.
        UserPreferences.onboardingDone = false
        UserPreferences.onboardingMigrationDone = false
        UserPreferences.storyIntroSeen = false
    }
    #endif

    private var signInWithAppleButton: some View {
        HStack(spacing: Space.sm) {
            Image(systemName: "apple.logo")
            Text("Sign in with Apple")
                .font(.bodyLarge.weight(.semibold))
        }
        .foregroundStyle(Color.brandTextTertiary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.md)
        .background(Color.brandSurfaceSunken)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(Color.brandDivider, lineWidth: 1)
        }
        .accessibilityHint("Disabled. Sign-in turns on once the Apple Developer account is in place.")
    }
}

#Preview {
    OnboardingGateView(onContinue: {})
}
