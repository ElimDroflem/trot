import SwiftUI
import SwiftData
import PhotosUI

/// Step 1 of the new-user onboarding. Three fields, one screen: photo
/// (optional), name (required), breed (required). Everything else
/// (DOB, weight, sex, neuter, activity, postcode, health flags) is
/// deferred — `AddDogFormState`'s defaults feed the breed-table-driven
/// daily target, which gracefully degrades to size/breed defaults when
/// DOB and weight aren't supplied.
///
/// On save, inserts the `Dog`, selects it on `AppState`, and fires
/// `onSaved`. Notifications aren't rescheduled here — that happens at
/// the end of the permissions step so the schedule reflects the user's
/// granted/denied choice.
struct OnboardingProfileStep: View {
    let onSaved: (Dog) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @State private var form = AddDogFormState()
    @State private var photoItem: PhotosPickerItem?
    @State private var saveError: String?
    @State private var showingBreedPicker = false

    var body: some View {
        ScrollView {
            VStack(spacing: Space.lg) {
                header

                photoSection(size: 200)

                FormCard(title: "Name") {
                    TextField("Bonnie", text: $form.name)
                        .font(.titleSmall)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .padding(.vertical, Space.xs)
                }

                FormCard(title: "Breed") {
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
                        .padding(.vertical, Space.xs)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(form.breedPrimary.isEmpty
                        ? "Choose breed"
                        : "Breed: \(form.breedPrimary). Tap to change.")
                }

                Spacer(minLength: Space.lg)

                Button(action: save) {
                    Text(continueTitle)
                        .font(.bodyLarge.weight(.semibold))
                        .foregroundStyle(Color.brandTextOnPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.md)
                        .background(canContinue ? Color.brandPrimary : Color.brandTextTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                }
                .disabled(!canContinue)

                Color.clear.frame(height: Space.lg)
            }
            .padding(.horizontal, Space.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.brandSurface.ignoresSafeArea())
        .onChange(of: photoItem) { _, newItem in
            Task { await loadPhoto(from: newItem) }
        }
        .sheet(isPresented: $showingBreedPicker) {
            BreedPickerView(selection: $form.breedPrimary) {
                showingBreedPicker = false
            }
        }
        .alert("Couldn't save", isPresented: errorBinding) {
            Button("OK") { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(spacing: Space.sm) {
            TrotLogo(size: 32)
                .padding(.bottom, Space.xs)
            Text("Show us your dog.")
                .font(.displayMedium)
                .foregroundStyle(Color.brandSecondary)
                .multilineTextAlignment(.center)
            Text("Three things and the book starts.")
                .font(.bodyMedium)
                .foregroundStyle(Color.brandTextSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Space.xl)
        .padding(.bottom, Space.md)
    }

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

    // MARK: - Validation + actions

    /// Local gate — the breed-table-driven `form.isValid` also requires
    /// `weightKg > 0` and `dateOfBirth <= now`, both of which are met by
    /// the form's defaults. We only expose name + breed in this step, so
    /// gating on those two is the right behaviour.
    private var canContinue: Bool {
        !form.trimmedName.isEmpty && !form.trimmedBreed.isEmpty
    }

    private var continueTitle: String {
        let name = form.trimmedName
        return name.isEmpty ? "Continue" : "Meet \(name)"
    }

    private func save() {
        guard canContinue, form.isValid else { return }
        do {
            let dog = form.makeDog()
            modelContext.insert(dog)
            try modelContext.save()
            appState.select(dog)
            onSaved(dog)
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

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )
    }
}
