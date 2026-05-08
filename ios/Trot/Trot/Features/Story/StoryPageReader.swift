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
        case caughtUp(title: String, subtitle: String)
        /// Path-choice footer. `lock` non-nil → buttons render but are
        /// disabled, with a one-line gating message under them
        /// ("Walk Luna 18 more minutes to unlock the next page.").
        /// Nil → fully enabled.
        case pickPath(lock: PathLock?, onPick: (_ choice: String, _ text: String, _ photo: Data?) -> Void)
    }

    /// Lock metadata for `pickPath`. Captured as a struct rather than a
    /// raw String so the renderer can tune icon/copy variants in one
    /// place and the call site can pass typed milestone info.
    struct PathLock: Equatable {
        let message: String
    }

    let dog: Dog
    let page: StoryPage
    let interaction: Interaction
    /// Tap on the "Read more" pill — caller opens the full-screen
    /// reader at this page. Lifted to the parent (`StoryView`) so the
    /// spine and any future entry point can share the same reader
    /// instance and overlay state.
    var onOpenFullReader: (() -> Void)? = nil
    /// Owned by `StoryView` so the loading state survives view-body
    /// re-renders triggered by the LLM round-trip and so the parent
    /// can reset it on success OR failure (this view never re-mounts
    /// during a single page-pick, so an internal `@State` stays stuck
    /// at `true` if the call fails).
    var isGenerating: Bool = false

    @State private var customText: String = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var isComposing: Bool = false

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
            GenrePageHeader(
                genre: genre,
                pageGlobalIndex: page.globalIndex,
                chapterIndex: page.chapter?.index ?? 1,
                pageInChapter: page.index
            )

            // Preview only — the page card is a teaser. The full prose
            // lives in `StoryFullPageReader`, reached via the pill at
            // the bottom of the card. Keeping the card short stops the
            // chapter shelf and Decisions footer from being pushed
            // halfway down the screen.
            GenreProseView(genre: genre, prose: page.prose, lineLimit: 4)

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
                            .stroke(genre.bookBorder, lineWidth: 1)
                    )
            }

            readMorePill
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .genreBookCard(genre)
    }

    /// Bottom-of-card affordance that opens `StoryFullPageReader`. The
    /// card itself shows the whole prose (so a quick read in the feed
    /// works), but tapping the pill commits to a distraction-free
    /// full-screen reading where the page is the iPhone screen.
    private var readMorePill: some View {
        HStack {
            Spacer()
            Button {
                onOpenFullReader?()
            } label: {
                HStack(spacing: 6) {
                    Text(readMoreLabel)
                        .font(.system(.caption, design: genre.bodyFontDesign).weight(.bold))
                        .tracking(1.5)
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(genre.accentColor)
                .padding(.horizontal, Space.sm)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .stroke(genre.accentColor.opacity(0.55), lineWidth: 1)
                        .background(Capsule().fill(genre.accentColor.opacity(0.12)))
                )
            }
            .buttonStyle(.plain)
        }
    }

    /// Genre-flavoured "Read more" copy on the pill. Each label is the
    /// idiom that genre's book would use to invite you in further.
    private var readMoreLabel: String {
        switch genre {
        case .murderMystery: return "READ THE FILE"
        case .horror:        return "GO ON…"
        case .fantasy:       return "READ THE FOLIO"
        case .sciFi:         return "OPEN FULL FILE"
        case .cosyMystery:   return "Settle in"
        case .adventure:     return "OPEN THE PAGE"
        }
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
        case .caughtUp(let title, let subtitle):
            calmFooter(
                icon: "moon.stars.fill",
                title: title,
                subtitle: subtitle
            )
        case .pickPath(let lock, let onPick):
            pickPathFooter(lock: lock, onPick: onPick)
        }
    }

    private func calmFooter(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: Space.md) {
            ZStack {
                Circle()
                    .fill(genre.accentColor.opacity(0.22))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(genre.accentColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.bodyLarge.weight(.semibold))
                    .foregroundStyle(genre.bookProseColor)
                Text(subtitle)
                    .font(.bodyMedium)
                    .foregroundStyle(genre.bookMetaColor)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .genreBookCard(genre, style: .compact)
    }

    private func pickPathFooter(lock: PathLock?, onPick: @escaping (String, String, Data?) -> Void) -> some View {
        let isLocked = lock != nil
        return VStack(spacing: Space.sm) {
            Text(whatNextLabel)
                .font(.system(.caption, design: genre.bodyFontDesign).weight(.bold))
                .tracking(2.0)
                .foregroundStyle(genre.accentColor)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Two big path buttons. Tap is suppressed when locked —
            // the buttons stay visible (so the user sees the tease) but
            // the action no-ops and the row dims.
            VStack(spacing: Space.xs) {
                pathButton(
                    label: page.pathChoiceA,
                    isLoading: isGenerating,
                    isLocked: isLocked
                ) {
                    guard !isLocked else { return }
                    onPick("a", "", nil)
                }
                pathButton(
                    label: page.pathChoiceB,
                    isLoading: isGenerating,
                    isLocked: isLocked
                ) {
                    guard !isLocked else { return }
                    onPick("b", "", nil)
                }
            }

            if let lock {
                // Single-line lock explainer beneath the buttons. The
                // padlock icon clarifies *why* the buttons look dimmed
                // — without it the disabled state could read as a bug.
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text(lock.message)
                        .font(.caption)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(genre.bookMetaColor)
                .padding(.top, 2)
            } else if isComposing {
                // Compose mode is hidden while locked — the user can't
                // submit anything yet, so the affordances would only
                // confuse.
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
        .frame(maxWidth: .infinity)
        .genreBookCard(genre, style: .compact)
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
    }

    /// Genre-flavoured header for the path-choice block. Each genre treats
    /// "what happens next" with its own typographic ritual — DECISIONS in
    /// noir, "what now…" handwritten in horror, FATES in fantasy,
    /// `> CHOOSE_PATH` in sci-fi, "What next?" in cosy, NEXT LEG in
    /// adventure.
    private var whatNextLabel: String {
        switch genre {
        case .murderMystery: return "DECISIONS"
        case .horror:        return "what now…"
        case .fantasy:       return "TWO FATES"
        case .sciFi:         return "> CHOOSE_PATH"
        case .cosyMystery:   return "What next?"
        case .adventure:     return "NEXT LEG"
        }
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
                .font(.system(.body, design: genre.bodyFontDesign))
                .foregroundStyle(genre.bookProseColor)
                .lineLimit(2...4)
                .padding(Space.sm)
                .background(genre.bookSurface.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .stroke(genre.bookBorder, lineWidth: 1)
                )
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
                        .foregroundStyle(genre.bookMetaColor)
                        .padding(.vertical, Space.sm)
                        .padding(.horizontal, Space.md)
                }
                .buttonStyle(.plain)
                Spacer()
                Button {
                    let text = customText.trimmingCharacters(in: .whitespacesAndNewlines)
                    let choice: String = photoData != nil ? "photo" : (text.isEmpty ? "" : "text")
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

    private func pathButton(label: String, isLoading: Bool, isLocked: Bool, action: @escaping () -> Void) -> some View {
        // When locked, render a padlock glyph instead of the genre's
        // path-leading icon — gives the user a clear visual signal at a
        // glance, before they read the explainer line below.
        let leadingIcon = isLocked ? "lock.fill" : pathButtonIcon
        let dimmed = isLoading || isLocked
        return Button(action: action) {
            HStack(spacing: Space.sm) {
                Image(systemName: leadingIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(genre.accentColor)
                Text(label.isEmpty ? "Carry on" : label)
                    .font(.system(.body, design: genre.bodyFontDesign).weight(.semibold))
                    .foregroundStyle(genre.bookProseColor)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(genre.bookSurface.opacity(0.65))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(genre.bookBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .buttonStyle(.plain)
        .disabled(dimmed)
        .opacity(dimmed ? 0.45 : 1.0)
    }

    /// Per-genre path-button leading glyph. Each one lives in the same
    /// idiom as the page header ornament so the button reads as part of
    /// the same book.
    private var pathButtonIcon: String {
        switch genre {
        case .murderMystery: return "circle.fill"            // typewriter-key bullet
        case .horror:        return "arrow.right"            // bare arrow, scratched
        case .fantasy:       return "sparkles"               // fated
        case .sciFi:         return "chevron.right.2"        // terminal continue
        case .cosyMystery:   return "leaf"                   // soft pull
        case .adventure:     return "location.north.fill"    // compass bearing
        }
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
        .background(Capsule().fill(genre.accentColor.opacity(0.18)))
    }

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let raw = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: raw) else { return }
        let downscaled = image.downscaledJPEGData()
        await MainActor.run { photoData = downscaled }
    }
}
