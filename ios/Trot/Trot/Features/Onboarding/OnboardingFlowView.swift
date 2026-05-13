import SwiftUI
import SwiftData

/// New-user onboarding coordinator. Six steps, one screen each:
///
///   1. **profile** — photo + name + breed (deferred fields use form
///       defaults). Saves the dog and selects it.
///   2. **genre** — `StoryGenrePicker`. Tap a card to preview, "Begin"
///       to commit. Atmosphere previews behind.
///   3. **scene** — `StoryScenePicker`. Picks where the prologue opens.
///   4. **generating** — `StoryGenerationProgress` while the LLM round-
///       trips. Falls back to a templated prologue on failure (handled
///       inside `StoryService`).
///   5. **prologue** — page 1 displayed in `StoryPageReader` with
///       `.awaitingWalk` interaction. The CTA advances to permissions.
///   6. **permissions** — "Want me to nudge you when there's a fresh
///       page?" Sets `UserPreferences.onboardingDone = true` on exit.
///
/// Resumes at the right step on `.onAppear` so a backgrounded mid-flow
/// is recoverable: no dog → step 1; dog without story → step 2; dog
/// with story but flag still false → step 6.
struct OnboardingFlowView: View {
    let onComplete: () -> Void

    @Query(filter: #Predicate<Dog> { $0.archivedAt == nil })
    private var activeDogs: [Dog]
    @Environment(\.modelContext) private var modelContext

    @State private var step: Step = .profile
    /// Currently-highlighted card in the genre picker. Lifted here so
    /// the atmosphere layer behind the picker can preview the world the
    /// moment a card is tapped — same pattern `StoryView` uses.
    @State private var pickerHover: StoryGenre?
    /// Locked once the user taps "Begin <Genre>". Atmosphere stays on
    /// this genre through the scene picker and the generation step so
    /// the run reads as one continuous world.
    @State private var pendingGenre: StoryGenre?
    /// Currently-highlighted scene in the scene picker.
    @State private var pickerSceneHover: StoryGenre.Scene?
    /// True between the moment the user taps "Begin" on the scene
    /// picker and the prologue persists. Drives the generation step's
    /// "Inking the first page…" view.
    @State private var isGenerating = false
    /// If a prologue generation somehow fails (shouldn't — `StoryService`
    /// uses templated fallbacks for the prologue specifically) we surface
    /// a retry alert.
    @State private var generationError: String?
    /// Drives the full-screen reader presented when the user taps the
    /// "Read the file"/"Read more" pill on the prologue page card. The
    /// card itself shows a 4-line teaser; the reader is the iPhone-
    /// screen-sized canonical view of the page.
    @State private var fullReaderPage: ProloguePageRef?

    enum Step {
        case profile
        case genre
        case scene
        case generating
        case prologue
        case permissions
    }

    /// First active dog by createdAt — the new-user case has at most one
    /// dog. The "add another dog" path doesn't go through this flow, so
    /// this is always the right pick during onboarding.
    private var dog: Dog? {
        activeDogs.sorted(by: { $0.createdAt < $1.createdAt }).first
    }

    var body: some View {
        ZStack {
            // Atmosphere source priority — mirrors `StoryView`'s
            // coalescing chain so a pick → scene → generating → prologue
            // run reads as one continuous world rather than three flashes.
            //   1. The just-locked dog story's genre (after pickGenre
            //      returns; persists across the prologue display).
            //   2. `pendingGenre` (during scene + generating, before the
            //      story is committed).
            //   3. `pickerHover` (during genre pick).
            // Profile + permissions steps render on the calm brand
            // surface — no atmosphere — so the asks read as deliberate.
            let atmosphereGenre = atmosphereGenre()
            if step != .profile, step != .permissions, let g = atmosphereGenre {
                GenreAtmosphereLayer(genre: g)
                GenreOverlay(genre: g)
            } else {
                Color.brandSurface.ignoresSafeArea()
            }

            content
        }
        .onAppear { resumeAtCurrentStep() }
        .alert("Couldn't write the page", isPresented: errorBinding) {
            Button("Try again") { retryGeneration() }
            Button("Cancel", role: .cancel) {
                generationError = nil
                step = .scene
            }
        } message: {
            Text(generationError ?? "")
        }
        .fullScreenCover(item: $fullReaderPage) { ref in
            // Single-page swipe stack for the prologue. Same reader
            // component the Story tab uses — keeps the visual identical
            // to what the user will see post-onboarding.
            StoryFullPageReader(
                genre: dog?.story?.genre ?? .adventure,
                pages: [ref.page],
                startIndex: 0
            ) { fullReaderPage = nil }
        }
    }

    // MARK: - Step router

    @ViewBuilder
    private var content: some View {
        switch step {
        case .profile:
            OnboardingProfileStep(onSaved: { _ in
                advance(to: .genre)
            })
        case .genre:
            StoryGenrePicker(selected: $pickerHover) { genre in
                pendingGenre = genre
                pickerSceneHover = nil
                advance(to: .scene)
            }
        case .scene:
            if let pendingGenre, let dog {
                StoryScenePicker(
                    genre: pendingGenre,
                    dogName: dog.name,
                    selected: $pickerSceneHover,
                    onBegin: { scene in
                        beginGeneration(genre: pendingGenre, scene: scene, for: dog)
                    },
                    onBack: {
                        pickerSceneHover = nil
                        self.pendingGenre = nil
                        advance(to: .genre)
                    }
                )
            } else {
                fallbackToGenre
            }
        case .generating:
            if let pendingGenre {
                StoryGenerationProgress(genre: pendingGenre)
            } else {
                fallbackToGenre
            }
        case .prologue:
            if let dog, let page = prologuePage(for: dog) {
                ScrollView {
                    VStack(spacing: Space.lg) {
                        prologueHeader(dog: dog)
                        StoryPageReader(
                            dog: dog,
                            page: page,
                            interaction: .awaitingWalk,
                            onOpenFullReader: { fullReaderPage = ProloguePageRef(page: page) }
                        )
                        prologueCTA
                        Color.clear.frame(height: Space.xl)
                    }
                    .padding(.horizontal, Space.md)
                    .padding(.top, Space.md)
                }
            } else {
                // No prologue page yet (race during state restore) —
                // fall back into generation if we have enough state.
                fallbackToGenre
            }
        case .permissions:
            if let dog {
                OnboardingPermissionsStep(dog: dog) {
                    onComplete()
                }
            } else {
                // Edge: permissions step with no dog. Shouldn't happen
                // — flag won't be set until the prologue exists. Recover
                // by sending the user back to start.
                fallbackToGenre
            }
        }
    }

    /// Renders briefly while the resume logic kicks the user back to
    /// `.genre`. Avoids a blank view if state is mid-restore.
    private var fallbackToGenre: some View {
        Color.clear.onAppear { advance(to: .genre) }
    }

    private func atmosphereGenre() -> StoryGenre? {
        if let genre = dog?.story?.genre { return genre }
        if let pendingGenre { return pendingGenre }
        return pickerHover
    }

    // MARK: - Header + CTA for the prologue step

    private func prologueHeader(dog: Dog) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(dog.name)'s story.")
                .font(.displayLarge)
                .atmosphereTextPrimary()
            if let genre = dog.story?.genre {
                HStack(spacing: 6) {
                    Image(systemName: genre.symbol)
                        .font(.caption.weight(.semibold))
                    Text(genre.displayName.uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(0.5)
                }
                .foregroundStyle(genre.accentColor)
                .padding(.horizontal, Space.sm)
                .padding(.vertical, 4)
                .background(Capsule().fill(genre.accentColor.opacity(0.15)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var prologueCTA: some View {
        Button(action: { advance(to: .permissions) }) {
            Text("What happens next?")
                .font(.bodyLarge.weight(.semibold))
                .foregroundStyle(Color.brandTextOnPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.md)
                .background(Color.brandPrimary)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
    }

    // MARK: - Actions

    private func advance(to next: Step) {
        withAnimation(.brandDefault) {
            step = next
        }
    }

    /// Restores the right step on first appear after a backgrounded mid-
    /// flow exit, app crash, or DEBUG reset. Wraps the pure-function
    /// `OnboardingFlowView.resumeStep(for:)` so the routing logic stays
    /// unit-testable.
    private func resumeAtCurrentStep() {
        step = OnboardingFlowView.resumeStep(for: dog)
    }

    /// Picks the right step to land on given the current persistence
    /// state. Pure: takes the active dog (or nil) and returns the
    /// step. Tested independently of the view body.
    static func resumeStep(for dog: Dog?) -> Step {
        guard let dog else { return .profile }
        if dog.story == nil { return .genre }
        // Dog has a story but `onboardingDone` is still false — the
        // user must have backgrounded mid-permissions step. Re-prompt
        // rather than resurrect the picker.
        return .permissions
    }

    private func beginGeneration(genre: StoryGenre, scene: StoryGenre.Scene, for dog: Dog) {
        // Lock pendingGenre BEFORE switching to .generating so the
        // atmosphere layer doesn't flicker on the transition.
        pendingGenre = genre
        isGenerating = true
        generationError = nil
        advance(to: .generating)

        Task {
            let result = await StoryService.pickGenre(
                genre,
                scene: scene,
                for: dog,
                modelContext: modelContext
            )
            await MainActor.run {
                isGenerating = false
                switch result {
                case .page:
                    advance(to: .prologue)
                case .failed(let message):
                    // Should not happen for the prologue (StoryService
                    // uses a templated fallback), but defensively show
                    // a retry path if the persistence step throws.
                    generationError = message
                case .chapterClosed, .bookFinished:
                    // Impossible on the first call — story has 1 page
                    // total at this point. Defensive fallthrough to
                    // prologue so the user isn't stuck.
                    advance(to: .prologue)
                }
            }
        }
    }

    private func retryGeneration() {
        guard let dog, let pendingGenre,
              let scene = pendingGenre.scenes.first(where: { $0.id == dog.story?.sceneRaw })
                ?? pendingGenre.scenes.first
        else {
            generationError = nil
            advance(to: .scene)
            return
        }
        generationError = nil
        beginGeneration(genre: pendingGenre, scene: scene, for: dog)
    }

    private func prologuePage(for dog: Dog) -> StoryPage? {
        let allPages = (dog.story?.chapters ?? []).flatMap { $0.pages ?? [] }
        return allPages.min(by: { $0.globalIndex < $1.globalIndex })
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { generationError != nil },
            set: { if !$0 { generationError = nil } }
        )
    }
}

/// Identifiable wrapper around the prologue `StoryPage` so
/// `.fullScreenCover(item:)` can drive on the page directly. Mirrors
/// `PageRef` in `StoryView` — kept private to this file so onboarding
/// owns its own presentation state.
private struct ProloguePageRef: Identifiable {
    let page: StoryPage
    var id: PersistentIdentifier { page.persistentModelID }
}
