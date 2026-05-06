import SwiftUI

/// Searchable breed picker used by `AddDogView`. Shows the 60 canonical UK breeds
/// from the bundled `BreedData.json`, with a "custom name" path for unknowns so
/// users with rare breeds, mixes, or out-of-table designer crosses can still proceed.
///
/// Design choices:
///   - One screen, searchable. No category drilling — 60 entries is small enough
///     for a flat list, and the search field handles long-tail discovery.
///   - "Type a custom name" sits at the top so it's discoverable without scrolling.
///     Selecting it reveals an inline TextField rather than a separate sheet.
///   - The current value is preserved when re-entering the picker.
struct BreedPickerView: View {
    @Binding var selection: String
    let onDismiss: () -> Void

    @State private var query: String = ""
    @State private var customMode: Bool = false
    @State private var customDraft: String = ""
    @FocusState private var customFieldFocused: Bool

    private let knownBreeds: [String] = ExerciseTargetService.knownBreedNames

    private var filteredBreeds: [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return knownBreeds }
        let needle = trimmed.lowercased()
        return knownBreeds.filter { $0.lowercased().contains(needle) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    customRow
                }
                Section("All breeds") {
                    if filteredBreeds.isEmpty {
                        emptyResult
                    } else {
                        ForEach(filteredBreeds, id: \.self) { breed in
                            Button(action: { commit(breed) }) {
                                HStack {
                                    Text(breed)
                                        .foregroundStyle(Color.brandTextPrimary)
                                    Spacer()
                                    if breed == selection {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.brandPrimary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Breed")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onDismiss() }
                        .tint(.brandPrimary)
                }
            }
            .onAppear {
                // If the current selection isn't in the table, prime the custom-mode
                // path so editing keeps showing the user's value rather than blanking it.
                if !selection.isEmpty && !knownBreeds.contains(selection) {
                    customMode = true
                    customDraft = selection
                }
            }
        }
    }

    @ViewBuilder
    private var customRow: some View {
        if customMode {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Custom breed")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brandTextTertiary)
                    .textCase(.uppercase)
                TextField("e.g. Sproodle, mongrel", text: $customDraft)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($customFieldFocused)
                    .onSubmit { commitCustom() }
                HStack(spacing: Space.sm) {
                    Button("Use this name") { commitCustom() }
                        .buttonStyle(.borderedProminent)
                        .tint(.brandPrimary)
                        .disabled(customDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Cancel") {
                        customMode = false
                        customDraft = ""
                    }
                    .buttonStyle(.bordered)
                    .tint(.brandTextSecondary)
                }
            }
            .padding(.vertical, Space.xs)
            .onAppear { customFieldFocused = true }
        } else {
            Button(action: {
                customMode = true
                customDraft = ""
            }) {
                HStack {
                    Image(systemName: "pencil")
                        .foregroundStyle(Color.brandPrimary)
                    Text("Type a custom name")
                        .foregroundStyle(Color.brandTextPrimary)
                    Spacer()
                    Text("for unlisted breeds and mixes")
                        .font(.caption)
                        .foregroundStyle(Color.brandTextTertiary)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyResult: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("No matches in the breed list.")
                .font(.bodyMedium)
                .foregroundStyle(Color.brandTextSecondary)
            Text("You can type a custom name above.")
                .font(.caption)
                .foregroundStyle(Color.brandTextTertiary)
        }
        .padding(.vertical, Space.sm)
    }

    private func commit(_ breed: String) {
        selection = breed
        onDismiss()
    }

    private func commitCustom() {
        let trimmed = customDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        selection = trimmed
        onDismiss()
    }
}

#Preview {
    @Previewable @State var pick = "Beagle"
    return BreedPickerView(selection: $pick, onDismiss: {})
}
