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
            let isNewWalk = editingWalk == nil
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
            // Journey progression + walk-complete celebration ONLY for new
            // walks. Editing an existing walk is silent (no celebration, no
            // toast) — the walk was already counted, and re-celebrating a
            // simple duration tweak would feel dishonest. Per Corey's
            // 2026-05-07 plan, edits stay quiet by design.
            if isNewWalk {
                let payloads = applyJourneyProgressAndCapture(minutes: form.durationMinutes)
                // Enqueue the celebration BEFORE dismiss so the overlay
                // is already queued on `appState` by the time the sheet
                // starts animating away. As the sheet slides off, the
                // overlay is revealed from underneath in one continuous
                // motion — no "dead air" gap. (Earlier code did the
                // opposite: dismiss + 350ms wait + enqueue, which felt
                // like the celebration only arrived "after I closed the
                // logging page.")
                for payload in payloads {
                    appState.pendingWalkCompletes.append(
                        payload.makeEvent(minutes: form.durationMinutes)
                    )
                }
                dismiss()
            } else {
                dismiss()
            }
        } catch {
            saveError = error.localizedDescription
        }
    }

    /// Advances each affected dog along their active route by the walk's
    /// duration and returns lightweight payloads for the post-dismiss
    /// enqueue. Returning value-typed payloads (rather than holding SwiftData
    /// `Dog` refs) keeps the post-dismiss Task safe from object-deletion
    /// races.
    ///
    /// Routeless dogs still produce a payload — `routeName` / `routeTotalMinutes`
    /// are nil and the overlay collapses the route bar.
    private func applyJourneyProgressAndCapture(minutes: Int) -> [PendingWalkCompletePayload] {
        guard minutes > 0 else { return [] }
        var payloads: [PendingWalkCompletePayload] = []
        for dog in dogs {
            let isFirstWalk = (dog.walks ?? []).count == 1
            let nextLandmarkName = JourneyService.nextLandmark(for: dog)?.landmark.name
            if let route = JourneyService.currentRoute(for: dog) {
                let oldMinutes = dog.routeProgressMinutes
                let application = JourneyService.applyWalk(minutes: minutes, to: dog)
                payloads.append(PendingWalkCompletePayload(
                    dogID: dog.persistentModelID,
                    dogName: dog.name.isEmpty ? "Your dog" : dog.name,
                    isFirstWalk: isFirstWalk,
                    oldProgressMinutes: oldMinutes,
                    newProgressMinutes: application.routeCompleted == nil ? dog.routeProgressMinutes : route.totalMinutes,
                    routeName: route.name,
                    routeTotalMinutes: route.totalMinutes,
                    minutesAdded: application.minutesAdded,
                    landmarksCrossed: application.landmarksCrossed,
                    routeCompletedName: application.routeCompleted?.name,
                    nextLandmarkName: nextLandmarkName
                ))
            } else {
                payloads.append(PendingWalkCompletePayload(
                    dogID: dog.persistentModelID,
                    dogName: dog.name.isEmpty ? "Your dog" : dog.name,
                    isFirstWalk: isFirstWalk,
                    oldProgressMinutes: 0,
                    newProgressMinutes: 0,
                    routeName: nil,
                    routeTotalMinutes: nil,
                    minutesAdded: 0,
                    landmarksCrossed: [],
                    routeCompletedName: nil,
                    nextLandmarkName: nil
                ))
            }
        }
        try? modelContext.save()
        return payloads
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
