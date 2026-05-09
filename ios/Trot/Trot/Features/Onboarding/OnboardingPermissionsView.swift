import SwiftUI

/// Final onboarding step. Sits between `AddDogView` and Home, fires the
/// notification permission ask in a clean context (instead of mid-
/// celebration on first paint, which is what bugs the user reported).
///
/// Doubles as the Story-mode discovery moment per `refactor.md` item 10:
/// new users land here, learn that the Story tab will write their dog
/// a book, and accept (or skip) notifications knowing why.
///
/// One-shot — gated by `UserDefaults.bool("trot.onboarding.permissionsSeen")`.
/// Once the user taps either CTA, the flag flips true and this view
/// won't re-appear, even on next launch.
///
/// HealthKit + Core Motion auth deliberately NOT here — those ship at
/// end-of-build alongside the walk-detection work, per `decisions.md`.
struct OnboardingPermissionsView: View {
    let dogName: String
    var onContinue: () -> Void

    @State private var isRequesting = false

    private var resolvedDogName: String {
        let trimmed = dogName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "your dog" : trimmed
    }

    var body: some View {
        ZStack {
            Color.brandSurface.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Spacer().frame(height: Space.xl)

                    TrotLogo(size: 56)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.bottom, Space.lg)

                    storyTeaser
                    notificationsAsk

                    Spacer().frame(height: Space.lg)

                    primaryCTA
                    secondaryCTA

                    Spacer().frame(height: Space.lg)
                }
                .padding(.horizontal, Space.lg)
            }
        }
    }

    private var storyTeaser: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text("A book for \(resolvedDogName).")
                .font(.displayMedium)
                .foregroundStyle(Color.brandTextPrimary)

            Text("The Story tab writes \(resolvedDogName) a book — one page per walk. Pick a genre, pick where it opens, and the first page lands the moment you tap Begin. Six worlds to choose from.")
                .font(.bodyLarge)
                .foregroundStyle(Color.brandTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var notificationsAsk: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.xs) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.brandPrimary)
                Text("A few well-timed nudges.")
                    .font(.titleSmall.weight(.semibold))
                    .foregroundStyle(Color.brandTextPrimary)
            }

            Text("Notifications let us tell you when there's a fresh page to read, a streak milestone, or the Sunday recap is ready. We'll keep them rare.")
                .font(.bodyMedium)
                .foregroundStyle(Color.brandTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brandSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg)
                .stroke(Color.brandDivider, lineWidth: 1)
        )
        .brandCardShadow()
    }

    private var primaryCTA: some View {
        Button(action: { Task { await allow() } }) {
            HStack(spacing: Space.xs) {
                if isRequesting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color.brandTextOnPrimary)
                }
                Text("Allow notifications")
                    .font(.bodyLarge.weight(.semibold))
            }
            .foregroundStyle(Color.brandTextOnPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.md)
            .background(Color.brandPrimary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .shadow(color: Color.brandPrimary.opacity(0.30), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(isRequesting)
    }

    private var secondaryCTA: some View {
        Button(action: skip) {
            Text("Maybe later")
                .font(.bodyMedium.weight(.semibold))
                .foregroundStyle(Color.brandPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.sm)
        }
        .buttonStyle(.plain)
        .disabled(isRequesting)
    }

    @MainActor
    private func allow() async {
        guard !isRequesting else { return }
        isRequesting = true
        _ = await NotificationService.requestPermission()
        markSeenAndContinue()
    }

    private func skip() {
        markSeenAndContinue()
    }

    private func markSeenAndContinue() {
        UserPreferences.permissionsSeen = true
        onContinue()
    }
}

#Preview {
    OnboardingPermissionsView(dogName: "Bonnie") { }
}
