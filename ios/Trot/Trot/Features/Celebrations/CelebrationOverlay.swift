import SwiftUI

/// Full-screen celebration moment for a first-week-loop milestone.
/// Per `brand.md`: Bricolage Grotesque for the title, brandCelebration spring,
/// "Show, don't shout — calm, not chirpy." One tap dismisses.
struct CelebrationOverlay: View {
    let celebration: PendingCelebration
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.brandSecondary.opacity(0.92).ignoresSafeArea()

            VStack(spacing: Space.lg) {
                Spacer()

                TrotLogo(size: 32)
                    .opacity(appeared ? 1 : 0)

                VStack(spacing: Space.md) {
                    Text(celebration.title)
                        .font(.displayMedium)
                        .foregroundStyle(Color.brandTextOnSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Space.lg)

                    Text(celebration.body)
                        .font(.bodyLarge)
                        .foregroundStyle(Color.brandTextOnSecondary.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Space.xl)
                }
                .scaleEffect(appeared ? 1 : 0.92)
                .opacity(appeared ? 1 : 0)

                Spacer()

                Button(action: onDismiss) {
                    Text("Continue")
                        .font(.bodyLarge.weight(.semibold))
                        .foregroundStyle(Color.brandSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.md)
                        .background(Color.brandTextOnSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                }
                .padding(.horizontal, Space.lg)
                .padding(.bottom, Space.xl)
                .opacity(appeared ? 1 : 0)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel("\(celebration.title). \(celebration.body). Tap to continue.")
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.brandCelebration.delay(0.05)) {
                    appeared = true
                }
            }
        }
        .transition(.opacity)
    }
}

#Preview {
    CelebrationOverlay(
        celebration: PendingCelebration(code: .firstWalk, dogName: "Luna"),
        onDismiss: {}
    )
}
