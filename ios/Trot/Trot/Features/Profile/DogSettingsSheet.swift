import SwiftUI
import SwiftData

/// Houses every form-list / settings card that used to live directly on the
/// Dog tab — Basics, Activity, "Why this target," Health, Walk windows,
/// Postcode, plus the Edit/Add another/Archive/Debug actions. Splitting these
/// into a sheet keeps the Dog tab clean (a player card, not a form), while
/// every detail is still one tap away behind a single "Settings" entry.
struct DogSettingsSheet: View {
    let dog: Dog

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Query(
        filter: #Predicate<Dog> { $0.archivedAt == nil },
        sort: \Dog.createdAt,
        order: .reverse
    )
    private var activeDogs: [Dog]

    @State private var showingEdit = false
    @State private var showingAddAnother = false
    @State private var showingArchiveConfirmation = false
    @State private var showingPostcodeEditor = false
    @State private var postcode: String = UserPreferences.postcode
    @State private var actionError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandSurface.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Space.lg) {
                        editProfileButton
                        basicsCard
                        activityCard
                        rationaleCard
                        healthCard
                        WalkWindowsCard(dog: dog)
                        postcodeCard
                        #if DEBUG
                        DebugToolsCard()
                        #endif
                        addAnotherDogButton
                        archiveButton
                        Color.clear.frame(height: Space.lg)
                    }
                    .padding(.horizontal, Space.md)
                    .padding(.top, Space.md)
                }
            }
            .navigationTitle("\(dog.name)'s settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .tint(.brandPrimary)
                }
            }
            .sheet(isPresented: $showingEdit) {
                NavigationStack {
                    AddDogView(editingDog: dog)
                        .navigationTitle("Edit profile")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .sheet(isPresented: $showingAddAnother) {
                NavigationStack {
                    AddDogView(showsCancelButton: true)
                        .navigationTitle("Add a dog")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .sheet(isPresented: $showingPostcodeEditor) {
                PostcodeEditSheet {
                    postcode = UserPreferences.postcode
                }
            }
            .confirmationDialog(
                "Archive this dog?",
                isPresented: $showingArchiveConfirmation,
                titleVisibility: .visible
            ) {
                Button("Archive", role: .destructive) { archiveActiveDog() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(archiveConfirmationMessage)
            }
            .alert("Something went wrong", isPresented: errorBinding) {
                Button("OK") { actionError = nil }
            } message: {
                Text(actionError ?? "")
            }
        }
    }

    // MARK: - Sections

    private var editProfileButton: some View {
        Button(action: { showingEdit = true }) {
            HStack(spacing: Space.xs) {
                Image(systemName: "pencil")
                Text("Edit \(dog.name)'s profile")
            }
            .font(.bodyLarge.weight(.semibold))
            .foregroundStyle(Color.brandPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.md)
            .background(Color.brandSurfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(Color.brandPrimary, lineWidth: 1.5)
            }
        }
    }

    private var basicsCard: some View {
        FormCard(title: "Basics") {
            FormRow(label: "Sex") { Text(sexLabel(dog.sex)) }
            FormDivider()
            FormRow(label: "Neutered") { Text(dog.isNeutered ? "Yes" : "No") }
            FormDivider()
            FormRow(label: "Weight") { Text(weightLabel(dog.weightKg)) }
            FormDivider()
            FormRow(label: "Date of birth") { Text(dobLabel(dog.dateOfBirth)) }
        }
    }

    private var activityCard: some View {
        FormCard(title: "Activity") {
            FormRow(label: "Daily target") {
                Text("\(dog.dailyTargetMinutes) min")
            }
            FormDivider()
            FormRow(label: "Activity level") {
                Text(activityLabel(dog.activityLevel))
            }
        }
    }

    @ViewBuilder
    private var rationaleCard: some View {
        let trimmed = dog.llmRationale.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            FormCard(title: "Why this target") {
                Text(trimmed)
                    .font(.bodyMedium)
                    .foregroundStyle(Color.brandTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Space.sm)
            }
        }
    }

    @ViewBuilder
    private var healthCard: some View {
        let conditions = healthConditions(dog: dog)
        let notes = dog.healthNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !conditions.isEmpty || !notes.isEmpty {
            FormCard(title: "Health") {
                ForEach(Array(conditions.enumerated()), id: \.offset) { index, condition in
                    if index > 0 { FormDivider() }
                    FormRow(label: condition) { Text("Yes") }
                }
                if !notes.isEmpty {
                    if !conditions.isEmpty { FormDivider() }
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text("Notes")
                            .font(.bodyMedium)
                            .foregroundStyle(Color.brandTextSecondary)
                        Text(notes)
                            .font(.bodyLarge)
                            .foregroundStyle(Color.brandTextPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, Space.sm)
                }
            }
        }
    }

    private var postcodeCard: some View {
        Button { showingPostcodeEditor = true } label: {
            FormCard(title: "Where you walk") {
                HStack {
                    if postcode.isEmpty {
                        Text("Add a postcode")
                            .foregroundStyle(Color.brandTextTertiary)
                    } else {
                        Text(postcode)
                            .foregroundStyle(Color.brandTextPrimary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.brandTextTertiary)
                }
                .padding(.vertical, Space.xs)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(postcode.isEmpty ? "Add a postcode" : "Postcode: \(postcode). Tap to change.")
    }

    private var addAnotherDogButton: some View {
        Button(action: { showingAddAnother = true }) {
            HStack(spacing: Space.xs) {
                Image(systemName: "plus")
                Text("Add another dog")
            }
            .font(.bodyLarge.weight(.semibold))
            .foregroundStyle(Color.brandPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.md)
            .background(Color.brandSurfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(Color.brandPrimary, lineWidth: 1.5)
            }
        }
        .padding(.top, Space.lg)
    }

    private var archiveButton: some View {
        Button(action: { showingArchiveConfirmation = true }) {
            Text("Archive \(dog.name)")
                .font(.bodyLarge.weight(.semibold))
                .foregroundStyle(Color.brandError)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.md)
        }
    }

    // MARK: - Actions

    private func archiveActiveDog() {
        dog.archivedAt = .now
        do {
            try modelContext.save()
            if appState.selectedDogID == dog.persistentModelID {
                appState.selectedDogID = nil
            }
            Task { await NotificationService.cancelAll() }
            dismiss()
        } catch {
            actionError = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private var archiveConfirmationMessage: String {
        if activeDogs.count == 1 {
            return "This is your only active dog. After archiving you'll be asked to add a new one."
        }
        return "Archived dogs are hidden from the active list. Walks and history are preserved."
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )
    }

    private func sexLabel(_ sex: Sex) -> String {
        switch sex {
        case .male: return "Male"
        case .female: return "Female"
        }
    }

    private func activityLabel(_ level: ActivityLevel) -> String {
        switch level {
        case .low: return "Low"
        case .moderate: return "Moderate"
        case .high: return "High"
        }
    }

    private func weightLabel(_ kg: Double) -> String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        let value = formatter.string(from: NSNumber(value: kg)) ?? "\(kg)"
        return "\(value) kg"
    }

    private func dobLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }

    private func healthConditions(dog: Dog) -> [String] {
        var conditions: [String] = []
        if dog.hasArthritis { conditions.append("Arthritis") }
        if dog.hasHipDysplasia { conditions.append("Hip dysplasia") }
        if dog.isBrachycephalic { conditions.append("Brachycephalic") }
        return conditions
    }
}
