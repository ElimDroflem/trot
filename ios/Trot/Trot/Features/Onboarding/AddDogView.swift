import SwiftUI
import SwiftData
import PhotosUI

/// Multi-step onboarding for adding a dog. New dogs walk through:
///
///   1. **Photo & name** — the big emotional anchor. Photo first per the
///      retention plan ("Show us your dog") so the user has something to
///      look at before they're asked anything else.
///   2. **Greeting** — generated dog-voice line ("Hi, I'm Luna. Walk?") via
///      `LLMService.onboardingCardLine`. Templated fallback on miss.
///   3. **Details** — breed, DOB, weight, sex, neutered, activity, health.
///      The full form, but already on the hook from steps 1-2.
///
/// Editing an existing dog skips straight to step 3 (no greeting moment for
/// repeat visits).
struct AddDogView: View {
    let editingDog: Dog?
    let showsCancelButton: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @State private var form: AddDogFormState
    @State private var photoItem: PhotosPickerItem?
    @State private var saveError: String?
    @State private var showingBreedPicker = false
    @State private var step: Step
    @State private var greetingLine: String?

    init(editingDog: Dog? = nil, showsCancelButton: Bool = false) {
        self.editingDog = editingDog
        self.showsCancelButton = showsCancelButton
        if let dog = editingDog {
            self._form = State(initialValue: AddDogFormState.from(dog))
            self._step = State(initialValue: .details)
        } else {
            self._form = State(initialValue: AddDogFormState())
            self._step = State(initialValue: .photoAndName)
        }
    }

    private var isEditing: Bool { editingDog != nil }
    private var showCancel: Bool { isEditing || showsCancelButton }

    enum Step { case photoAndName, greeting, details }

    var body: some View {
        ZStack {
            Color.brandSurface.ignoresSafeArea()

            switch step {
            case .photoAndName: photoAndNameStep
            case .greeting:     greetingStep
            case .details:      detailsStep
            }
        }
        .toolbar {
            if showCancel, step == .photoAndName || step == .details && isEditing {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .tint(.brandPrimary)
                }
            }
            if !isEditing, step == .greeting || step == .details {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        withAnimation(.brandDefault) {
                            step = (step == .greeting) ? .photoAndName : .greeting
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .tint(.brandPrimary)
                    .accessibilityLabel("Back")
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
        .sheet(isPresented: $showingBreedPicker) {
            BreedPickerView(selection: $form.breedPrimary) {
                showingBreedPicker = false
            }
        }
    }

    // MARK: - Step 1: photo & name

    private var photoAndNameStep: some View {
        ScrollView {
            VStack(spacing: Space.lg) {
                VStack(spacing: Space.sm) {
                    TrotLogo(size: 32)
                        .padding(.bottom, Space.xs)
                    Text("Show us your dog.")
                        .font(.displayMedium)
                        .foregroundStyle(Color.brandSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, Space.xl)
                .padding(.bottom, Space.md)

                photoSection(size: 200)

                FormCard(title: "Name") {
                    TextField("Luna", text: $form.name)
                        .font(.titleSmall)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .padding(.vertical, Space.xs)
                }

                Spacer(minLength: Space.lg)

                Button(action: continueFromPhotoAndName) {
                    Text(continueButtonTitle)
                        .font(.bodyLarge.weight(.semibold))
                        .foregroundStyle(Color.brandTextOnPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.md)
                        .background(canContinueFromPhotoAndName ? Color.brandPrimary : Color.brandTextTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                }
                .disabled(!canContinueFromPhotoAndName)

                Color.clear.frame(height: Space.lg)
            }
            .padding(.horizontal, Space.md)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var canContinueFromPhotoAndName: Bool {
        !form.trimmedName.isEmpty
    }

    private var continueButtonTitle: String {
        let name = form.trimmedName
        return name.isEmpty ? "Continue" : "Meet \(name)"
    }

    private func continueFromPhotoAndName() {
        guard canContinueFromPhotoAndName else { return }
        withAnimation(.brandDefault) {
            step = .greeting
        }
    }

    // MARK: - Step 2: generated greeting

    private var greetingStep: some View {
        VStack(spacing: Space.lg) {
            Spacer()

            photoSection(size: 220)

            VStack(spacing: Space.md) {
                Text(form.trimmedName)
                    .font(.displayLarge)
                    .foregroundStyle(Color.brandSecondary)
                    .multilineTextAlignment(.center)

                Text(displayedGreeting)
                    .font(.titleMedium)
                    .italic()
                    .foregroundStyle(Color.brandTextPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.lg)
                    .frame(minHeight: 56)
            }

            Spacer()

            Button(action: continueFromGreeting) {
                Text("Tell Trot more about \(form.trimmedName)")
                    .font(.bodyLarge.weight(.semibold))
                    .foregroundStyle(Color.brandTextOnPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Space.md)
                    .background(Color.brandPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            }
            .padding(.horizontal, Space.md)
            .padding(.bottom, Space.lg)
        }
        .padding(.horizontal, Space.md)
        .task(id: form.trimmedName) {
            await fetchGreeting()
        }
    }

    /// Show the LLM line if it returned, otherwise a templated fallback that
    /// uses the user's actual dog name. Never empty.
    private var displayedGreeting: String {
        if let line = greetingLine, !line.isEmpty {
            return line
        }
        return "\u{201C}Hi, I'm \(form.trimmedName). Let's go.\u{201D}"
    }

    private func fetchGreeting() async {
        let name = form.trimmedName
        guard !name.isEmpty else { return }
        let line = await LLMService.onboardingCardLine(name: name)
        await MainActor.run {
            withAnimation(.brandDefault) {
                greetingLine = line
            }
        }
    }

    private func continueFromGreeting() {
        withAnimation(.brandDefault) {
            step = .details
        }
    }

    // MARK: - Step 3: details (the rest of the form)

    private var detailsStep: some View {
        ScrollView {
            VStack(spacing: Space.lg) {
                detailsHeader
                if isEditing {
                    photoSection(size: 140)
                    nameCardForEditing
                }
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

    @ViewBuilder
    private var detailsHeader: some View {
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
                Text("\(form.trimmedName)'s details")
                    .font(.displayMedium)
                    .foregroundStyle(Color.brandSecondary)
                    .multilineTextAlignment(.center)
                Text("Helps Trot tailor the daily walk target.")
                    .font(.bodyMedium)
                    .foregroundStyle(Color.brandTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, Space.md)
            .padding(.bottom, Space.sm)
        }
    }

    /// Shown only in editing mode — the new-dog flow has its own dedicated
    /// name+photo step, so name there isn't part of the details card.
    private var nameCardForEditing: some View {
        FormCard(title: "Name") {
            TextField("Luna", text: $form.name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.next)
        }
    }

    // MARK: - Shared sections

    private func photoSection(size: CGFloat) -> some View {
        PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
            ZStack {
                Circle()
                    .fill(Color.brandSurfaceSunken)
                    .frame(width: size, height: size)

                if let data = form.photoData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                } else {
                    VStack(spacing: Space.xs) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: size * 0.2))
                            .foregroundStyle(Color.brandTextTertiary)
                        Text("Add photo")
                            .font(.caption)
                            .foregroundStyle(Color.brandTextTertiary)
                    }
                }
            }
            .overlay {
                Circle().stroke(Color.brandPrimary.opacity(form.photoData == nil ? 0 : 1), lineWidth: 3)
            }
        }
        .accessibilityLabel(form.photoData == nil ? "Add a photo" : "Change photo")
    }

    private var basicsCard: some View {
        FormCard(title: "Basics") {
            FormRow(label: "Breed") {
                Button(action: { showingBreedPicker = true }) {
                    HStack(spacing: Space.xs) {
                        Text(form.breedPrimary.isEmpty ? "Choose breed" : form.breedPrimary)
                            .foregroundStyle(form.breedPrimary.isEmpty
                                ? Color.brandTextTertiary
                                : Color.brandTextPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.brandTextTertiary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(form.breedPrimary.isEmpty
                    ? "Choose breed"
                    : "Breed: \(form.breedPrimary). Tap to change.")
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
            // Newly added dogs become the selected one — both for first-run onboarding
            // and for "add another dog" flows. Edits leave selection alone.
            if !isEditing {
                appState.select(savedDog)
            }
            Task { await NotificationService.reschedule(for: savedDog) }
            if showCancel { dismiss() }
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
