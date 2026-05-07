import SwiftUI

/// Single-field sheet for entering or updating the user's postcode. Reused
/// from the empty Today-tile state ("Add a postcode") and from the Profile
/// "Where you walk" card ("Change postcode"). Postcode is per-user (not per
/// dog) and is normalised inside `UserPreferences` on save.
///
/// Validation is intentionally light — UK postcodes have a permissive enough
/// format that a hard regex would reject odd-but-valid cases. We accept any
/// non-empty 3-10 character input and let the geocoder confirm. If geocoding
/// fails downstream the WalkWindowTile shows "Forecast unavailable" and the
/// user can come back here to fix it.
struct PostcodeEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var entry: String

    /// Optional callback fired once the new value has been written. Today tile
    /// and Profile card use it to refresh their copy of the postcode.
    var onSave: (() -> Void)?

    init(onSave: (() -> Void)? = nil) {
        self._entry = State(initialValue: UserPreferences.postcode)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandSurface.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Space.lg) {
                        VStack(alignment: .leading, spacing: Space.xs) {
                            Text("Your postcode")
                                .font(.displayMedium)
                                .foregroundStyle(Color.brandSecondary)
                            Text("Used for the daily walk-window forecast. Trot never tracks your live location.")
                                .font(.bodyMedium)
                                .foregroundStyle(Color.brandTextSecondary)
                        }

                        FormCard(title: "Postcode") {
                            VStack(alignment: .leading, spacing: Space.xs) {
                                TextField("e.g. SW1A 1AA", text: $entry)
                                    .font(.titleSmall)
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()
                                    .submitLabel(.done)
                                    .onSubmit(save)
                                    .padding(.vertical, Space.xs)
                                Text("On holiday or moved? Update it here any time.")
                                    .font(.caption)
                                    .foregroundStyle(Color.brandTextTertiary)
                            }
                        }

                        Button(action: save) {
                            Text(canSave ? "Save" : "Save")
                                .font(.bodyLarge.weight(.semibold))
                                .foregroundStyle(Color.brandTextOnPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Space.md)
                                .background(canSave ? Color.brandPrimary : Color.brandTextTertiary)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        }
                        .disabled(!canSave)
                        .padding(.top, Space.sm)

                        if !UserPreferences.postcode.isEmpty {
                            Button(role: .destructive, action: clear) {
                                Text("Remove postcode")
                                    .font(.bodyMedium.weight(.semibold))
                                    .foregroundStyle(Color.brandError)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, Space.md)
                            }
                        }
                    }
                    .padding(.horizontal, Space.md)
                    .padding(.top, Space.lg)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .tint(.brandPrimary)
                }
            }
        }
    }

    private var canSave: Bool {
        let trimmed = entry.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 3 && trimmed.count <= 10
    }

    private func save() {
        guard canSave else { return }
        UserPreferences.postcode = entry
        onSave?()
        dismiss()
    }

    private func clear() {
        UserPreferences.postcode = ""
        onSave?()
        dismiss()
    }
}
