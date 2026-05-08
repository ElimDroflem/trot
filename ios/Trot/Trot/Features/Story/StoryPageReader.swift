import SwiftUI
import PhotosUI

/// The page reader. Renders the latest page as the centrepiece — genre-
/// themed body font, dog photo at the top of the spread, and one of three
/// interactive footers depending on what state the story is in.
///
/// Three footer modes:
///   - **awaitingWalk**: "Page two unlocks on your next walk." No
///     interaction; just a soft pull.
///   - **caughtUp**: "Today's page is in. Come back tomorrow." Same idea.
///   - **pickPath**: the two AI-generated path buttons + "Write
///     something" + "Add a photo" affordances. The user's choice fires
///     the next-page generation.
struct StoryPageReader: View {
    enum Interaction {
        case awaitingWalk
        case caughtUp
        case pickPath(onPick: (_ choice: String, _ text: String, _ photo: Data?) -> Void)
    }

    let dog: Dog
    let page: StoryPage
    let interaction: Interaction

    @State private var customText: String = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var isComposing: Bool = false
    @State private var isGenerating: Bool = false

    private var genre: StoryGenre { dog.story?.genre ?? .adventure }

    var body: some View {
        VStack(spacing: Space.md) {
            pageCard
            footer
        }
    }

    // MARK: - Page card

    private var pageCard: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                Text("Page \(page.globalIndex)")
                    .font(.caption.weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(genre.accentColor)
                Spacer()
                if let chapter = page.chapter {
                    Text("Chapter \(chapter.index) · \(page.index)/5")
                        .font(.caption.weight(.semibold))
                        .tracking(0.5)
                        .foregroundStyle(Color.brandTextTertiary)
                }
            }

            Text(page.prose)
                .font(.system(.body, design: genre.bodyFontDesign))
                .foregroundStyle(Color.brandTextPrimary)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            if let data = page.photo, let image = UIImage(data: data) {
                // Photo the user attached when they directed this page —
                // their memory of the day, sitting alongside the prose.
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.md)
                            .stroke(genre.accentColor.opacity(0.4), lineWidth: 1)
                    )
            }
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brandSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .brandCardShadow()
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        switch interaction {
        case .awaitingWalk:
            calmFooter(
                icon: "figure.walk",
                title: "Page two unlocks on your next walk.",
                subtitle: "The book grows by a page each walk. The dog decides what counts."
            )
        case .caughtUp:
            calmFooter(
                icon: "moon.stars.fill",
                title: "Today's page is in.",
                subtitle: "Come back after your next walk for the next bit."
            )
        case .pickPath(let onPick):
            pickPathFooter(onPick: onPick)
        }
    }

    private func calmFooter(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: Space.md) {
            ZStack {
                Circle()
                    .fill(genre.accentColor.opacity(0.18))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(genre.accentColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.bodyLarge.weight(.semibold))
                    .foregroundStyle(Color.brandTextPrimary)
                Text(subtitle)
                    .font(.bodyMedium)
                    .foregroundStyle(Color.brandTextSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity)
        .background(Color.brandSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .brandCardShadow()
    }

    private func pickPathFooter(onPick: @escaping (String, String, Data?) -> Void) -> some View {
        VStack(spacing: Space.sm) {
            Text("WHAT NEXT")
                .font(.caption.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(genre.accentColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Two big path buttons.
            VStack(spacing: Space.xs) {
                pathButton(
                    label: page.pathChoiceA,
                    accent: genre.accentColor,
                    isLoading: isGenerating
                ) {
                    isGenerating = true
                    onPick("a", "", nil)
                }
                pathButton(
                    label: page.pathChoiceB,
                    accent: genre.accentColor,
                    isLoading: isGenerating
                ) {
                    isGenerating = true
                    onPick("b", "", nil)
                }
            }

            // Compose mode (text + photo). Tap "Write something" or
            // "Add a photo" to expand the panel.
            if isComposing {
                composeBlock(onPick: onPick)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                HStack(spacing: Space.sm) {
                    Spacer()
                    secondaryButton(label: "Write something", icon: "pencil") {
                        withAnimation(.brandDefault) { isComposing = true }
                    }
                    PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                        secondaryLabel(label: "Add a photo", icon: "camera.fill")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity)
        .background(Color.brandSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .brandCardShadow()
        .onChange(of: photoItem) { _, newItem in
            Task { await loadPhoto(from: newItem) }
        }
        .onChange(of: photoData) { _, _ in
            // Photo arrived — auto-expand compose so user can add a
            // caption alongside the photo before submitting.
            if photoData != nil {
                withAnimation(.brandDefault) { isComposing = true }
            }
        }
        .onAppear { isGenerating = false }
    }

    private func composeBlock(onPick: @escaping (String, String, Data?) -> Void) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            if let photoData, let image = UIImage(data: photoData) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    Button {
                        withAnimation(.brandDefault) {
                            self.photoData = nil
                            self.photoItem = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.white)
                            .background(Color.black.opacity(0.55).clipShape(Circle()))
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }
            }

            TextField("What happens next?", text: $customText, axis: .vertical)
                .font(.bodyMedium)
                .foregroundStyle(Color.brandTextPrimary)
                .lineLimit(2...4)
                .padding(Space.sm)
                .background(Color.brandSurface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))

            HStack(spacing: Space.sm) {
                Button {
                    withAnimation(.brandDefault) {
                        isComposing = false
                        customText = ""
                        photoData = nil
                        photoItem = nil
                    }
                } label: {
                    Text("Cancel")
                        .font(.bodyMedium.weight(.semibold))
                        .foregroundStyle(Color.brandTextSecondary)
                        .padding(.vertical, Space.sm)
                        .padding(.horizontal, Space.md)
                }
                .buttonStyle(.plain)
                Spacer()
                Button {
                    let text = customText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let choice: String = photoData != nil ? "photo" : (text.isEmpty ? "" : "text")
                    isGenerating = true
                    onPick(choice, text, photoData)
                } label: {
                    Text("Write the next page")
                        .font(.bodyMedium.weight(.semibold))
                        .foregroundStyle(Color.brandTextOnPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.sm)
                        .background(genre.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                }
                .buttonStyle(.plain)
                .disabled(isGenerating || (customText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && photoData == nil))
            }
        }
        .padding(Space.sm)
    }

    private func pathButton(label: String, accent: Color, isLoading: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Space.sm) {
                Image(systemName: "arrow.forward.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accent)
                Text(label.isEmpty ? "Carry on" : label)
                    .font(.bodyLarge.weight(.semibold))
                    .foregroundStyle(Color.brandTextPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.brandSurface)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(accent.opacity(0.4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
        .opacity(isLoading ? 0.5 : 1.0)
    }

    private func secondaryButton(label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            secondaryLabel(label: label, icon: icon)
        }
        .buttonStyle(.plain)
    }

    private func secondaryLabel(label: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(label)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(genre.accentColor)
        .padding(.horizontal, Space.sm)
        .padding(.vertical, 6)
        .background(Capsule().fill(genre.accentColor.opacity(0.12)))
    }

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let raw = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: raw) else { return }
        let downscaled = image.downscaledJPEGData()
        await MainActor.run { photoData = downscaled }
    }
}
