import SwiftUI
import SwiftData

struct LogWalkSheet: View {
    let dogs: [Dog]
    let editingWalk: Walk?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var form: LogWalkFormState
    @State private var saveError: String?
    @State private var showingDeleteConfirmation = false

    init(dogs: [Dog], editingWalk: Walk? = nil, initialDate: Date? = nil) {
        self.dogs = dogs
        self.editingWalk = editingWalk
        if let walk = editingWalk {
            self._form = State(initialValue: LogWalkFormState.from(walk))
        } else {
            var state = LogWalkFormState()
            if let initialDate {
                // Use the supplied calendar day, but keep the time as "now" so it feels natural.
                let calendar = Calendar.current
                let dayStart = calendar.startOfDay(for: initialDate)
                let nowComponents = calendar.dateComponents([.hour, .minute], from: .now)
                let combined = calendar.date(
                    bySettingHour: nowComponents.hour ?? 12,
                    minute: nowComponents.minute ?? 0,
                    second: 0,
                    of: dayStart
                ) ?? initialDate
                // Clamp to today if the initial date is today and the time would be in the future
                state.startedAt = min(combined, .now)
            }
            self._form = State(initialValue: state)
        }
    }

    private var isEditing: Bool { editingWalk != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandSurface.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Space.lg) {
                        header
                        whenCard
                        durationCard
                        notesCard
                        saveButton
                        if isEditing { deleteButton }
                        Color.clear.frame(height: Space.lg)
                    }
                    .padding(.horizontal, Space.md)
                    .padding(.top, Space.md)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(isEditing ? "Edit walk" : "Log a walk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .tint(.brandPrimary)
                }
            }
            .alert("Couldn't save", isPresented: errorBinding) {
                Button("OK") { saveError = nil }
            } message: {
                Text(saveError ?? "")
            }
            .confirmationDialog(
                "Delete this walk?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { deleteWalk() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This can't be undone.")
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: Space.xs) {
            Text(headlineText)
                .font(.titleLarge)
                .foregroundStyle(Color.brandSecondary)
                .multilineTextAlignment(.center)
            if !isEditing && dogs.count > 1 {
                Text(dogNamesList)
                    .font(.bodyMedium)
                    .foregroundStyle(Color.brandTextSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, Space.sm)
    }

    private var whenCard: some View {
        FormCard(title: "When") {
            FormRow(label: "Date & time") {
                DatePicker(
                    "",
                    selection: $form.startedAt,
                    in: ...Date(),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
                .tint(.brandPrimary)
            }
        }
    }

    private var durationCard: some View {
        FormCard(title: "Duration") {
            FormRow(label: "Minutes") {
                HStack(spacing: Space.xs) {
                    TextField("30", value: $form.durationMinutes, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 80)
                    Stepper("", value: $form.durationMinutes, in: 1...300, step: 5)
                        .labelsHidden()
                        .tint(.brandPrimary)
                }
            }
        }
    }

    private var notesCard: some View {
        FormCard(title: "Notes") {
            TextField(
                "Optional",
                text: $form.notes,
                axis: .vertical
            )
            .font(.bodyLarge)
            .foregroundStyle(Color.brandTextPrimary)
            .lineLimit(2...4)
            .padding(.vertical, Space.xs)
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            Text("Save")
                .font(.bodyLarge.weight(.semibold))
                .foregroundStyle(Color.brandTextOnPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.md)
                .background(form.isValid ? Color.brandPrimary : Color.brandTextTertiary)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .disabled(!form.isValid)
        .padding(.top, Space.sm)
    }

    private var deleteButton: some View {
        Button(action: { showingDeleteConfirmation = true }) {
            Text("Delete walk")
                .font(.bodyLarge.weight(.semibold))
                .foregroundStyle(Color.brandError)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.md)
        }
        .padding(.top, Space.xs)
    }

    // MARK: - Actions

    private func save() {
        guard form.isValid else { return }
        do {
            if let editingWalk {
                form.apply(to: editingWalk)
            } else {
                guard !dogs.isEmpty else { return }
                let walk = form.makeWalk(for: dogs)
                modelContext.insert(walk)
            }
            try modelContext.save()
            rescheduleNotifications()
            checkMilestones()
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func deleteWalk() {
        guard let editingWalk else { return }
        modelContext.delete(editingWalk)
        do {
            try modelContext.save()
            rescheduleNotifications()
            // No milestone check on delete — beats are forward-only.
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    /// First-week loop: any walk save can fire one or more milestone beats.
    /// Saves the fired-set onto each affected dog and enqueues celebrations on AppState.
    private func checkMilestones() {
        for dog in dogs {
            let new = MilestoneService.newMilestones(for: dog)
            guard !new.isEmpty else { continue }
            MilestoneService.markFired(new, on: dog)
            appState.enqueueCelebrations(new, for: dog)
        }
        // Persist firedMilestones changes — failure here only loses a refire suppression,
        // not user data, so we swallow rather than re-surface.
        try? modelContext.save()
    }

    private func rescheduleNotifications() {
        guard let dog = dogs.first else { return }
        Task { await NotificationService.reschedule(for: dog) }
    }

    // MARK: - Helpers

    private var headlineText: String {
        if isEditing { return "Edit walk." }
        if let only = dogs.first, dogs.count == 1 {
            return "Log a walk with \(only.name)."
        }
        return "Log a walk."
    }

    private var dogNamesList: String {
        let names = dogs.map(\.name)
        switch names.count {
        case 0: return ""
        case 1: return names[0]
        case 2: return "\(names[0]) and \(names[1])"
        default:
            let head = names.dropLast().joined(separator: ", ")
            return "\(head), and \(names.last ?? "")"
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )
    }
}

#Preview {
    LogWalkSheet(dogs: [])
        .modelContainer(for: [Dog.self, Walk.self, WalkWindow.self], inMemory: true)
}
