import SwiftUI

/// Brand-styled bottom-sheet confirmation. Replaces the system
/// `.confirmationDialog` (iOS-glass action sheet) where the off-brand
/// styling reads as system chrome rather than part of the app.
///
/// Present via `.sheet(isPresented:)` with explicit detents so the sheet
/// pops up to a small height and the full screen content stays visible
/// behind it.
///
/// Usage:
/// ```
/// .sheet(isPresented: $showingDiscardConfirm) {
///     BrandConfirmSheet(
///         title: "Discard this walk?",
///         message: "The time so far won't be saved.",
///         primary: .init(label: "Discard", role: .destructive) { ... },
///         secondary: .init(label: "Keep walking")
///     )
///     .presentationDetents([.height(280)])
///     .presentationDragIndicator(.visible)
/// }
/// ```
struct BrandConfirmSheet: View {
    struct Action {
        enum Role { case normal, destructive }

        let label: String
        let role: Role
        let action: (() -> Void)?

        init(label: String, role: Role = .normal, action: (() -> Void)? = nil) {
            self.label = label
            self.role = role
            self.action = action
        }
    }

    let title: String
    let message: String?
    let primary: Action
    let secondary: Action?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Space.md) {
            VStack(spacing: Space.xs) {
                Text(title)
                    .font(.titleSmall)
                    .foregroundStyle(Color.brandTextPrimary)
                    .multilineTextAlignment(.center)
                if let message {
                    Text(message)
                        .font(.bodyMedium)
                        .foregroundStyle(Color.brandTextSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.md)

            Spacer(minLength: 0)

            VStack(spacing: Space.sm) {
                primaryButton
                if let secondary {
                    secondaryButton(secondary)
                }
            }
            .padding(.horizontal, Space.lg)
            .padding(.bottom, Space.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.brandSurface)
    }

    private var primaryButton: some View {
        Button {
            primary.action?()
            dismiss()
        } label: {
            Text(primary.label)
                .font(.bodyLarge.weight(.semibold))
                .foregroundStyle(Color.brandTextOnPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.md)
                .background(primary.role == .destructive ? Color.brandError : Color.brandPrimary)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
    }

    private func secondaryButton(_ action: Action) -> some View {
        Button {
            action.action?()
            dismiss()
        } label: {
            Text(action.label)
                .font(.bodyLarge.weight(.semibold))
                .foregroundStyle(Color.brandPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.md)
        }
    }
}

#Preview {
    Color.brandSurface.ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            BrandConfirmSheet(
                title: "Discard this walk?",
                message: "The time so far won't be saved.",
                primary: .init(label: "Discard", role: .destructive),
                secondary: .init(label: "Keep walking")
            )
            .presentationDetents([.height(280)])
        }
}
