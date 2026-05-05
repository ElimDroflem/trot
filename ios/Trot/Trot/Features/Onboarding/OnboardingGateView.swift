import SwiftUI

struct OnboardingGateView: View {
    var onContinue: () -> Void

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
                }
                .padding(.horizontal, Space.lg)
                .padding(.bottom, Space.xl)
            }
        }
    }

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
