import SwiftUI
import SwiftData
import PhotosUI

struct AddDogView: View {
    let editingDog: Dog?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var form: AddDogFormState
    @State private var photoItem: PhotosPickerItem?
    @State private var saveError: String?

    init(editingDog: Dog? = nil) {
        self.editingDog = editingDog
        if let dog = editingDog {
            self._form = State(initialValue: AddDogFormState.from(dog))
        } else {
            self._form = State(initialValue: AddDogFormState())
        }
    }

    private var isEditing: Bool { editingDog != nil }

    var body: some View {
        ZStack {
            Color.brandSurface.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Space.lg) {
                    header
                    photoSection
                    basicsCard
                    bodyCard
                    activityCard
                    healthCard
                    saveButton
                    Color.clear.frame(height: Space.lg)
                }
                .padding(.horizontal, Space.md)
                .padding(.top, Space.md)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .toolbar {
            if isEditing {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .tint(.brandPrimary)
                }
            }
        }
        .onChange(of: photoItem) { _, newItem in
            Task { await loadPhoto(from: newItem) }
        }
        .alert("Couldn't save", isPresented: errorBinding) {
            Button("OK") { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var header: some View {
        if isEditing {
            VStack(spacing: Space.sm) {
                Text("Edit \(form.trimmedName.isEmpty ? "profile" : form.trimmedName).")
                    .font(.displayMedium)
                    .foregroundStyle(Color.brandSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, Space.sm)
            .padding(.bottom, Space.sm)
        } else {
            VStack(spacing: Space.sm) {
                TrotLogo(size: 32)
                    .padding(.bottom, Space.xs)
                Text("Tell us about your dog.")
                    .font(.displayMedium)
                    .foregroundStyle(Color.brandSecondary)
                    .multilineTextAlignment(.center)
                Text("We'll use this to set a sensible daily walking target.")
                    .font(.bodyMedium)
                    .foregroundStyle(Color.brandTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, Space.md)
            .padding(.bottom, Space.sm)
        }
    }

    private var photoSection: some View {
        PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
            ZStack {
                Circle()
                    .fill(Color.brandSurfaceSunken)
                    .frame(width: 140, height: 140)

                if let data = form.photoData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 140, height: 140)
                        .clipShape(Circle())
                } else {
                    VStack(spacing: Space.xs) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.brandTextTertiary)
                        Text("Add photo")
                            .font(.caption)
                            .foregroundStyle(Color.brandTextTertiary)
                    }
                }
            }
            .overlay {
                Circle().stroke(Color.brandDivider, lineWidth: 1)
            }
        }
        .accessibilityLabel(form.photoData == nil ? "Add a photo" : "Change photo")
    }

    private var basicsCard: some View {
        FormCard(title: "Basics") {
            FormRow(label: "Name") {
                TextField("Luna", text: $form.name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
            }
            FormDivider()
            FormRow(label: "Breed") {
                TextField("Beagle", text: $form.breedPrimary)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
            }
            FormDivider()
            FormRow(label: "Date of birth") {
                DatePicker(
                    "",
                    selection: $form.dateOfBirth,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .labelsHidden()
                .tint(.brandPrimary)
            }
        }
    }

    private var bodyCard: some View {
        FormCard(title: "Details") {
            FormRow(label: "Weight") {
                HStack(spacing: Space.xs) {
                    TextField("10", value: $form.weightKg, format: .number.precision(.fractionLength(0...1)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Text("kg")
                        .font(.bodyMedium)
                        .foregroundStyle(Color.brandTextSecondary)
                }
            }
            FormDivider()
            FormRow(label: "Sex") {
                Picker("Sex", selection: $form.sex) {
                    Text("Female").tag(Sex.female)
                    Text("Male").tag(Sex.male)
                }
                .pickerStyle(.segmented)
            }
            FormDivider()
            FormRow(label: "Neutered") {
                Toggle("", isOn: $form.isNeutered)
                    .labelsHidden()
                    .tint(.brandPrimary)
            }
        }
    }

    private var activityCard: some View {
        FormCard(title: "Activity level") {
            Picker("Activity", selection: $form.activityLevel) {
                Text("Low").tag(ActivityLevel.low)
                Text("Moderate").tag(ActivityLevel.moderate)
                Text("High").tag(ActivityLevel.high)
            }
            .pickerStyle(.segmented)
            .padding(.vertical, Space.xs)

            Text(activityLevelDescription)
                .font(.caption)
                .foregroundStyle(Color.brandTextTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var healthCard: some View {
        FormCard(title: "Health") {
            FormRow(label: "Arthritis") {
                Toggle("", isOn: $form.hasArthritis)
                    .labelsHidden()
                    .tint(.brandPrimary)
            }
            FormDivider()
            FormRow(label: "Hip dysplasia") {
                Toggle("", isOn: $form.hasHipDysplasia)
                    .labelsHidden()
                    .tint(.brandPrimary)
            }
            FormDivider()
            FormRow(label: "Brachycephalic") {
                Toggle("", isOn: $form.isBrachycephalic)
                    .labelsHidden()
                    .tint(.brandPrimary)
            }
            FormDivider()
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Anything else")
                    .font(.bodyMedium)
                    .foregroundStyle(Color.brandTextSecondary)
                TextField(
                    "Optional notes",
                    text: $form.healthNotes,
                    axis: .vertical
                )
                .lineLimit(2...4)
            }
            .padding(.vertical, Space.xs)
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            Text(isEditing ? "Save changes" : "Save")
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
        guard form.isValid else { return }
        do {
            let savedDog: Dog
            if let editingDog {
                form.apply(to: editingDog)
                savedDog = editingDog
            } else {
                let dog = form.makeDog()
                modelContext.insert(dog)
                savedDog = dog
            }
            try modelContext.save()
            Task { await NotificationService.reschedule(for: savedDog) }
            if isEditing { dismiss() }
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard let raw = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: raw)
            else { return }
            let downscaled = image.downscaledJPEGData()
            await MainActor.run {
                form.photoData = downscaled
            }
        } catch {
            await MainActor.run {
                saveError = "Couldn't load that photo. Try another."
            }
        }
    }

    private var activityLevelDescription: String {
        switch form.activityLevel {
        case .low: return "Senior, recovering, or low-energy by nature."
        case .moderate: return "Most adult dogs sit here."
        case .high: return "Working breeds and high-energy adults."
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
    AddDogView()
        .modelContainer(for: [Dog.self, Walk.self, WalkWindow.self], inMemory: true)
}
