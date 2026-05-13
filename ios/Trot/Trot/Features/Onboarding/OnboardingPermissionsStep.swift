import SwiftUI

/// Final step of the new-user onboarding. Fires AFTER the user has read
/// page 1 of the prologue — the value moment they were promised. The
/// ask is earned: the app has just delivered a personalised story for
/// their dog, so "want me to nudge you when there's a fresh page?" lands
/// without feeling like a permission interruption.
///
/// On exit (whichever button), `UserPreferences.onboardingDone` flips
/// true and `RootView` re-evaluates straight to `HomeView`. The
/// "Maybe later" path leaves the user able to grant permission later
/// via the walk-window reminder toggle (which surfaces an "Open
/// Settings" hint when denied).
struct OnboardingPermissionsStep: View {
    let dog: Dog
    let onComplete: () -> Void

    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: Space.lg) {
            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.18))
                    .frame(width: 96, height: 96)
                Image(systemName: "bell.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(Color.brandPrimary)
            }

            VStack(spacing: Space.sm) {
                Text("Fresh page?")
                    .font(.displayLarge)
                    .foregroundStyle(Color.brandSecondary)
                    .multilineTextAlignment(.center)
                Text("A nudge when \(dog.name)'s next page is ready.\nNothing else, no spam.")
                    .font(.titleSmall)
                    .foregroundStyle(Color.brandTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.lg)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            VStack(spacing: Space.sm) {
                Button(action: grant) {
                    Text("Yes, nudge me")
                        .font(.bodyLarge.weight(.semibold))
                        .foregroundStyle(Color.brandTextOnPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.md)
                        .background(Color.brandPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                }
                .disabled(isRequesting)

                Button(action: skip) {
                    Text("Maybe later")
                        .font(.bodyLarge.weight(.semibold))
                        .foregroundStyle(Color.brandTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.md)
                }
                .disabled(isRequesting)
            }
            .padding(.horizontal, Space.md)
            .padding(.bottom, Space.lg)
        }
        .padding(.horizontal, Space.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.brandSurface.ignoresSafeArea())
    }

    private func grant() {
        guard !isRequesting else { return }
        isRequesting = true
        Task {
            _ = await NotificationService.requestPermission()
            await NotificationService.reschedule(for: dog)
            await MainActor.run {
                UserPreferences.onboardingDone = true
                onComplete()
            }
        }
    }

    private func skip() {
        guard !isRequesting else { return }
        UserPreferences.onboardingDone = true
        onComplete()
    }
}
