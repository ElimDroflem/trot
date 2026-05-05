import SwiftUI
import SwiftData

struct DogProfileView: View {
    @Query(
        filter: #Predicate<Dog> { $0.archivedAt == nil },
        sort: \Dog.createdAt,
        order: .reverse
    )
    private var activeDogs: [Dog]

    @Environment(\.modelContext) private var modelContext

    @State private var showingEdit = false
    @State private var showingArchiveConfirmation = false
    @State private var actionError: String?

    private var activeDog: Dog? { activeDogs.first }

    var body: some View {
        ZStack {
            Color.brandSurface.ignoresSafeArea()

            if let dog = activeDog {
                ScrollView {
                    VStack(spacing: Space.lg) {
                        photoHeader(dog: dog)
                        basicsCard(dog: dog)
                        activityCard(dog: dog)
                        healthCard(dog: dog)
                        WalkWindowsCard(dog: dog)
                        archiveButton(dog: dog)
                        Color.clear.frame(height: Space.lg)
                    }
                    .padding(.horizontal, Space.md)
                    .padding(.top, Space.md)
                }
            } else {
                emptyState
            }
        }
        .sheet(isPresented: $showingEdit) {
            if let dog = activeDog {
                NavigationStack {
                    AddDogView(editingDog: dog)
                        .navigationTitle("Edit profile")
                        .navigationBarTitleDisplayMode(.inline)
                }
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

    // MARK: - Sections

    private func photoHeader(dog: Dog) -> some View {
        VStack(spacing: Space.md) {
            ZStack {
                Circle()
                    .fill(Color.brandSecondaryTint)
                    .frame(width: 140, height: 140)

                if let data = dog.photo, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 140, height: 140)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.brandSecondary.opacity(0.5))
                }
            }
            .overlay {
                Circle().stroke(Color.brandDivider, lineWidth: 1)
            }

            VStack(spacing: Space.xs) {
                Text(dog.name)
                    .font(.titleLarge)
                    .foregroundStyle(Color.brandTextPrimary)
                if !dog.breedPrimary.isEmpty {
                    Text(breedAndAgeLine(dog: dog))
                        .font(.bodyMedium)
                        .foregroundStyle(Color.brandTextSecondary)
                }
            }

            Button(action: { showingEdit = true }) {
                Text("Edit profile")
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
            .padding(.top, Space.sm)
        }
        .padding(.top, Space.sm)
    }

    private func basicsCard(dog: Dog) -> some View {
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

    private func activityCard(dog: Dog) -> some View {
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
    private func healthCard(dog: Dog) -> some View {
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

    private func archiveButton(dog: Dog) -> some View {
        Button(action: { showingArchiveConfirmation = true }) {
            Text("Archive \(dog.name)")
                .font(.bodyLarge.weight(.semibold))
                .foregroundStyle(Color.brandError)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.md)
        }
        .padding(.top, Space.lg)
    }

    private var emptyState: some View {
        VStack(spacing: Space.md) {
            Image(systemName: "pawprint.circle")
                .font(.system(size: 48))
                .foregroundStyle(Color.brandTextTertiary)
            Text("No dog selected.")
                .font(.titleMedium)
                .foregroundStyle(Color.brandTextSecondary)
        }
        .padding(Space.xl)
    }

    // MARK: - Actions

    private func archiveActiveDog() {
        guard let dog = activeDog else { return }
        dog.archivedAt = .now
        do {
            try modelContext.save()
            // After archiving, the @Query on RootView will fall through to AddDogView
            // (or to the next active dog if multi-dog). Cancel all notifications now;
            // RootView's scenePhase handler will reschedule for the next dog if any.
            Task { await NotificationService.cancelAll() }
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

    private func breedAndAgeLine(dog: Dog) -> String {
        let breed = dog.breedPrimary
        let years = ageInYears(dog: dog)
        return "\(breed) · \(years)"
    }

    private func ageInYears(dog: Dog) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: dog.dateOfBirth, to: .now)
        let years = components.year ?? 0
        let months = components.month ?? 0
        if years == 0 {
            return "\(max(0, months)) mo"
        }
        return years == 1 ? "1 yr" : "\(years) yrs"
    }

    private func healthConditions(dog: Dog) -> [String] {
        var conditions: [String] = []
        if dog.hasArthritis { conditions.append("Arthritis") }
        if dog.hasHipDysplasia { conditions.append("Hip dysplasia") }
        if dog.isBrachycephalic { conditions.append("Brachycephalic") }
        return conditions
    }
}

#Preview {
    DogProfileView()
        .modelContainer(for: [Dog.self, Walk.self, WalkWindow.self], inMemory: true)
}
