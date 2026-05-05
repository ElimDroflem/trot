import SwiftUI
import SwiftData

struct LogWalkSheet: View {
    let dogs: [Dog]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var form = LogWalkFormState()
    @State private var saveError: String?

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
                        Color.clear.frame(height: Space.lg)
                    }
                    .padding(.horizontal, Space.md)
                    .padding(.top, Space.md)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Log a walk")
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
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: Space.xs) {
            Text(headlineText)
                .font(.titleLarge)
                .foregroundStyle(Color.brandSecondary)
                .multilineTextAlignment(.center)
            if dogs.count > 1 {
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

    // MARK: - Actions

    private func save() {
        guard form.isValid, !dogs.isEmpty else { return }
        let walk = form.makeWalk(for: dogs)
        modelContext.insert(walk)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private var headlineText: String {
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
