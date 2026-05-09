import SwiftUI
import SwiftData
import PhotosUI

/// Trot's narrative tab. The user and their dog are protagonists of an
/// AI-written book that grows by one page per walk. Genre is picked once
/// per dog and locks for the run of the story.
///
/// Five visual states (driven by `StoryService.currentState`):
///   - **noStory** → genre picker. Magical first impression.
///   - **awaitingFirstWalk** → prologue is written but no walks yet.
///       Show the prologue + a "first walk unlocks page 2" pull.
///   - **pageReady** → walks happened today, no page yet. Show the
///       latest page + the two path-choice buttons + write/photo
///       affordances. User picks a direction, page generates.
///   - **caughtUp** → today's page is written. Show it. Tomorrow brings
///       the next page.
///   - **chapterClosed** → an unconsumed close exists. Full-screen
///       celebration takeover: chapter title, closing line, "begin next
///       chapter" CTA. Marks the chapter seen on dismiss.
///
/// Below the active surface: "The story so far" — horizontal scroll of
/// completed chapter spreads, themed by genre. Tap to read the whole
/// chapter in a full-screen reader.
struct StoryView: View {
    @Query(filter: #Predicate<Dog> { $0.archivedAt == nil })
    private var activeDogs: [Dog]
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    /// Forced refresh after async generation finishes.
    @State private var refreshTick: Int = 0
    /// Whether the celebration overlay is up. Driven by
    /// `StoryService.unseenClosedChapter` plus a local dismiss flag so
    /// the user can tap through. Wrapped in an Identifiable struct
    /// because `.sheet(item:)` needs Identifiable and SwiftData @Models
    /// don't conform.
    @State private var celebrationChapter: ChapterRef?
    /// Cooldown so we don't pop the celebration overlay twice in a row
    /// after the same dismiss in a single session.
    @State private var dismissedCelebrationIDs: Set<PersistentIdentifier> = []
    /// Currently-open chapter reader (full-screen preview of a closed chapter).
    @State private var readingChapter: ChapterRef?
    /// True from the moment the user taps "Begin <Genre>" until the
    /// prologue page has been written (LLM round-trip, ~5–10s typical).
    /// Drives the in-between "Writing the first page…" state so the
    /// picker doesn't sit visually frozen during the call.
    @State private var pendingGenrePick: StoryGenre?
    /// Mirror of `UserPreferences.storyIntroSeen` so SwiftUI re-renders
    /// when the user taps Begin on the one-shot intro. Initialised from
    /// the persistent flag, then locally + persistently flipped true.
    @State private var storyIntroSeen = UserPreferences.storyIntroSeen
    /// Set when the user has committed a genre but hasn't yet committed
    /// a scene. Drives the routing to `StoryScenePicker`. Distinct from
    /// `pendingGenrePick` (which fires once the LLM call kicks off) so
    /// the user can still go Back to the genre picker before they
    /// commit the scene.
    @State private var pendingSceneFor: StoryGenre?
    /// The scene card currently highlighted in the scene picker.
    /// Mirrors `pickerHover` for genres.
    @State private var sceneHover: StoryGenre.Scene?
    /// The genre card currently highlighted in the picker. Lifted from
    /// `StoryGenrePicker` so the atmosphere layer can preview the world
    /// behind the picker the moment a card is tapped — selection is
    /// preview, "Begin" is commit.
    @State private var pickerHover: StoryGenre?
    /// The page the full-screen reader should open at. Setting it
    /// presents the reader (`fullScreenCover(item:)`); clearing it
    /// dismisses. Both the page card's "Read more" pill and the
    /// chapter spine rows feed this state, so the reader instance is
    /// the same regardless of where the user opened it from.
    @State private var fullReaderStart: PageRef?
    /// True from the moment the user taps a path button until the
    /// LLM call resolves (success or failure). Owned here — not
    /// inside `StoryPageReader` — so it survives view-body re-renders
    /// during the round-trip and is reliably reset on failure (the
    /// reader never re-mounts during a single pick, so an internal
    /// `@State` would stay stuck at `true` if the call errored).
    @State private var isGeneratingPage: Bool = false
    /// Last-error message for the page-pick LLM call. Surfaces a
    /// banner above the page card with a Retry button; nil hides the
    /// banner. Replaces silent `_ = await` failure that left the
    /// user looking at unchanged UI.
    @State private var pageGenerationError: String?
    /// Stashed args from the most recent path-pick so the Retry button
    /// can re-fire the same request without the user re-typing or
    /// re-selecting a photo. Cleared on success.
    @State private var lastPickArgs: PickArgs?

    private var selectedDog: Dog? { appState.selectedDog(from: activeDogs) }

    var body: some View {
        // Atmosphere source priority (highest first):
        //   1. `pendingGenrePick` — user has tapped Begin on the scene
        //      step, prologue is being written. Atmosphere stays locked
        //      on the chosen genre while the LLM works.
        //   2. `pendingSceneFor` — genre is committed, user is on the
        //      scene picker. Atmosphere stays on the chosen genre so
        //      the transition genre→scene→writing is one continuous
        //      world, not three flashes.
        //   3. `selectedDog?.story?.genre` — story is committed; the
        //      genre is locked for the run of the book.
        //   4. `pickerHover` — user is browsing the genre picker, has
        //      tapped a card to preview.
        // Falling through to nil means we render the weather layer
        // (no story, nothing previewed).
        let genre = pendingGenrePick ?? pendingSceneFor ?? selectedDog?.story?.genre ?? pickerHover

        ZStack {
            // Base brand surface so the bottom of the screen always reads
            // as cream regardless of the genre overlay.
            LinearGradient(
                colors: [Color.brandSurface, Color.brandSurfaceSunken],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Genre atmosphere replaces the WeatherMoodLayer on this tab.
            // No genre yet → fall back to the weather layer so the picker
            // sits on the same atmosphere as the rest of the app, which
            // helps it feel anticipatory rather than abstract.
            if let genre {
                GenreAtmosphereLayer(genre: genre)
                // Pervasive medium overlay — film grain, scanlines,
                // vignette etc. — sits between the sky and the cards so
                // the whole page feels like a different *book*, not just
                // a different colour.
                GenreOverlay(genre: genre)
            } else {
                WeatherMoodLayer()
            }

            content
        }
        .edgeGlass()
        .sheet(item: $readingChapter) { ref in
            StoryChapterReader(chapter: ref.chapter, genre: genre ?? .adventure)
        }
        .fullScreenCover(item: $celebrationChapter) { ref in
            StoryChapterCloseOverlay(chapter: ref.chapter, genre: genre ?? .adventure) {
                StoryService.markChapterSeen(ref.chapter)
                try? modelContext.save()
                dismissedCelebrationIDs.insert(ref.chapter.persistentModelID)
                celebrationChapter = nil
            }
        }
        .fullScreenCover(item: $fullReaderStart) { ref in
            // Swipe-stack source: every page in the dog's story across
            // every chapter, in reading order. So the user can swipe
            // back from chapter 2 page 3 to chapter 1 page 1 without
            // closing and reopening anything.
            let pages = orderedStoryPages
            let startIndex = pages.firstIndex { $0.persistentModelID == ref.page.persistentModelID } ?? max(0, pages.count - 1)
            StoryFullPageReader(
                genre: genre ?? selectedDog?.story?.genre ?? .adventure,
                pages: pages,
                startIndex: startIndex
            ) { fullReaderStart = nil }
        }
        .task(id: refreshTick) {
            checkForUnseenChapter()
        }
        .onAppear { checkForUnseenChapter() }
    }

    // MARK: - Content router

    @ViewBuilder
    private var content: some View {
        if let dog = selectedDog {
            // While the prologue is being written, suppress the picker
            // and the noStory branch — the user tapped Begin, the picker
            // should disappear immediately.
            if let pending = pendingGenrePick {
                StoryGenerationProgress(genre: pending)
            } else if let pendingGenre = pendingSceneFor {
                // Genre committed, scene not yet picked. Atmosphere stays
                // locked on `pendingGenre` (priority #2 in the source
                // chain above), so the transition feels like a page
                // turn inside the same book.
                StoryScenePicker(
                    genre: pendingGenre,
                    dogName: dog.name,
                    selected: $sceneHover,
                    onBegin: { scene in
                        // Hand off to the LLM call. Set pendingGenrePick
                        // BEFORE clearing pendingSceneFor so the
                        // atmosphere coalescing chain never momentarily
                        // falls through to the weather layer.
                        pendingGenrePick = pendingGenre
                        pendingSceneFor = nil
                        Task { await pickGenre(pendingGenre, scene: scene, for: dog) }
                    },
                    onBack: {
                        sceneHover = nil
                        pendingSceneFor = nil
                    }
                )
            } else {
                routedContent(for: dog)
            }
        } else {
            EmptyStoryPlaceholder()
        }
    }

    @ViewBuilder
    private func routedContent(for dog: Dog) -> some View {
        let state = StoryService.currentState(for: dog)
        switch state {
        case .noStory:
            // First-time visitors get a one-shot intro that explains
            // what Story mode is BEFORE the genre-pick decision.
            // `storyIntroSeen` flips true on Begin and the picker
            // takes over for this and every subsequent visit.
            if !storyIntroSeen {
                StoryIntroView(dogName: dog.name) {
                    UserPreferences.storyIntroSeen = true
                    withAnimation(.brandDefault) {
                        storyIntroSeen = true
                    }
                }
            } else {
                StoryGenrePicker(selected: $pickerHover) { genre in
                    // Genre committed → move to the scene picker. Atmosphere
                    // is already on this genre via `pickerHover`; setting
                    // `pendingSceneFor` keeps it locked there while the
                    // user picks where the story opens.
                    withAnimation(.brandDefault) {
                        pendingSceneFor = genre
                    }
                }
            }
        case .awaitingFirstWalk(let page):
            ScrollView {
                VStack(spacing: Space.lg) {
                    StoryHeader(dog: dog, story: dog.story)
                    StoryPageReader(
                        dog: dog,
                        page: page,
                        interaction: .awaitingWalk,
                        onOpenFullReader: { fullReaderStart = PageRef(page: page) }
                    )
                    chapterShelf(dog: dog)
                    Color.clear.frame(height: Space.lg)
                }
                .padding(.horizontal, Space.md)
                .padding(.top, Space.md)
            }
        case .pageReady(let page), .caughtUp(let page, _):
            ScrollView {
                VStack(spacing: Space.lg) {
                    StoryHeader(dog: dog, story: dog.story)
                    ChapterSpine(
                        chapter: dog.story?.currentChapter,
                        currentPage: page,
                        genre: dog.story?.genre ?? .adventure,
                        onTapPage: { tappedPage in
                            fullReaderStart = PageRef(page: tappedPage)
                        }
                    )
                    if isGeneratingPage {
                        GenerationStatusBanner(
                            genre: dog.story?.genre ?? .adventure
                        )
                    } else if let message = pageGenerationError {
                        GenerationErrorBanner(
                            genre: dog.story?.genre ?? .adventure,
                            message: message,
                            onRetry: { retryLastPick(for: dog) },
                            onDismiss: { pageGenerationError = nil }
                        )
                    }
                    StoryPageReader(
                        dog: dog,
                        page: page,
                        interaction: pageInteraction(for: state, dog: dog),
                        onOpenFullReader: { fullReaderStart = PageRef(page: page) },
                        isGenerating: isGeneratingPage
                    )
                    chapterShelf(dog: dog)
                    Color.clear.frame(height: Space.lg)
                }
                .padding(.horizontal, Space.md)
                .padding(.top, Space.md)
            }
        case .chapterClosed:
            // Should be transient — the .task picks it up and shows
            // the overlay. Render the caught-up reader underneath
            // for the instant before the overlay paints.
            if let page = dog.story?.currentChapter?.orderedPages.last {
                ScrollView {
                    VStack(spacing: Space.lg) {
                        StoryHeader(dog: dog, story: dog.story)
                        StoryPageReader(
                            dog: dog,
                            page: page,
                            interaction: .caughtUp(
                                title: "Today's page is in.",
                                subtitle: "Come back after your next walk for the next bit."
                            ),
                            onOpenFullReader: { fullReaderStart = PageRef(page: page) }
                        )
                        chapterShelf(dog: dog)
                        Color.clear.frame(height: Space.lg)
                    }
                    .padding(.horizontal, Space.md)
                    .padding(.top, Space.md)
                }
            }
        }
    }

    /// Maps the service's page-state to the reader's interaction model.
    /// Encapsulates the "show locked path-choice vs calm caughtUp" rule
    /// here so the body stays readable.
    private func pageInteraction(
        for state: StoryService.State,
        dog: Dog
    ) -> StoryPageReader.Interaction {
        let onPick: (String, String, Data?) -> Void = { choice, text, photo in
            Task {
                await generateNext(for: dog, choice: choice, text: text, photo: photo)
            }
        }
        switch state {
        case .pageReady:
            return .pickPath(lock: nil, onPick: onPick)
        case .caughtUp(_, .needMoreMinutes(let minutesNeeded, _)):
            // User has walked but not enough yet. Buttons render but
            // disabled, with the milestone tease underneath.
            let dogName = dog.name.isEmpty ? "your dog" : dog.name
            let suffix = minutesNeeded == 1 ? "minute" : "minutes"
            return .pickPath(
                lock: .init(message: "Walk \(dogName) \(minutesNeeded) more \(suffix) to unlock the next page."),
                onPick: onPick
            )
        case .caughtUp(_, .dailyCapHit):
            return .caughtUp(
                title: "Two pages today.",
                subtitle: "The book waits for tomorrow — the dog can only carry the story so far in a day."
            )
        default:
            // Defensive fallback — every other state is handled by the
            // outer router before this helper runs.
            return .caughtUp(
                title: "Today's page is in.",
                subtitle: "Come back after your next walk for the next bit."
            )
        }
    }

    private func chapterShelf(dog: Dog) -> some View {
        StoryChapterShelf(
            dog: dog,
            genre: dog.story?.genre ?? .adventure,
            onTap: { readingChapter = ChapterRef(chapter: $0) }
        )
    }

    /// All pages from the selected dog's story, in reading order — used
    /// by the full-screen swipe reader so a user can move freely
    /// across chapter boundaries.
    private var orderedStoryPages: [StoryPage] {
        let chapters = (selectedDog?.story?.chapters ?? [])
            .sorted { $0.index < $1.index }
        return chapters.flatMap { chapter in
            (chapter.pages ?? []).sorted { $0.index < $1.index }
        }
    }

    // MARK: - Actions

    private func pickGenre(_ genre: StoryGenre, scene: StoryGenre.Scene, for dog: Dog) async {
        _ = await StoryService.pickGenre(genre, scene: scene, for: dog, modelContext: modelContext)
        // Bump refreshTick BEFORE clearing pendingGenrePick so SwiftUI
        // sees the state change and re-evaluates the body once. Then
        // drop pendingGenrePick — at this point the prologue page
        // exists, so the router lands on `.awaitingFirstWalk` instead
        // of falling back to the picker.
        await MainActor.run {
            refreshTick &+= 1
            pendingGenrePick = nil
            // Clear the picker preview state too — at this point the
            // story is committed and the genre source comes from
            // `dog.story.genre`. Leaving this set is harmless (it's
            // last in the coalescing chain) but tidier to nil it.
            pickerHover = nil
            sceneHover = nil
        }
    }

    private func generateNext(
        for dog: Dog,
        choice: String,
        text: String,
        photo: Data?
    ) async {
        // Stash args for the Retry button to re-fire the same request
        // without forcing the user to re-pick a path or re-attach a
        // photo.
        lastPickArgs = PickArgs(choice: choice, text: text, photo: photo)
        isGeneratingPage = true
        pageGenerationError = nil

        let result = await StoryService.generateNextPage(
            for: dog,
            userChoice: choice,
            userText: text,
            imageJPEG: photo,
            modelContext: modelContext
        )
        // Always reset the loading flag and bump refresh — both
        // success (new page exists, body should re-evaluate) and
        // failure (banner needs to render, buttons need to reactivate
        // so the user can retry).
        await MainActor.run {
            isGeneratingPage = false
            switch result {
            case .page, .chapterClosed:
                lastPickArgs = nil
                pageGenerationError = nil
            case .failed(let message):
                pageGenerationError = message
            }
            refreshTick &+= 1
        }
    }

    /// Re-fires the most recent path pick. Wired to the error banner's
    /// Retry button — same payload, no UI re-entry required.
    private func retryLastPick(for dog: Dog) {
        guard let args = lastPickArgs else { return }
        Task {
            await generateNext(
                for: dog,
                choice: args.choice,
                text: args.text,
                photo: args.photo
            )
        }
    }

    private func checkForUnseenChapter() {
        guard let dog = selectedDog,
              let chapter = StoryService.unseenClosedChapter(for: dog),
              !dismissedCelebrationIDs.contains(chapter.persistentModelID) else {
            return
        }
        celebrationChapter = ChapterRef(chapter: chapter)
    }
}

/// Identifiable wrapper around a `StoryChapter` so `.sheet(item:)` can
/// drive on a chapter without requiring `StoryChapter` itself to conform
/// to Identifiable (which collides with SwiftData @Model's macro-
/// generated conformances).
private struct ChapterRef: Identifiable {
    let chapter: StoryChapter
    var id: PersistentIdentifier { chapter.persistentModelID }
}

/// Identifiable wrapper around a `StoryPage` for `.fullScreenCover(item:)`.
/// Same SwiftData @Model / Identifiable workaround as `ChapterRef`.
private struct PageRef: Identifiable {
    let page: StoryPage
    var id: PersistentIdentifier { page.persistentModelID }
}

/// Captures the user's most recent path-pick so the Retry button on the
/// page-generation error banner can re-fire the same request without
/// forcing them to re-tap a path or re-attach a photo.
private struct PickArgs {
    let choice: String
    let text: String
    let photo: Data?
}

// MARK: - Generation banners

/// Shown above the page card while the LLM is writing the next page.
/// Mirrors the genre's book chrome so it reads as part of the story
/// rather than a system toast — a calligraphic "the storyteller is at
/// the wheel" cue, not a spinner.
private struct GenerationStatusBanner: View {
    let genre: StoryGenre

    var body: some View {
        HStack(spacing: Space.sm) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(genre.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .font(.system(.callout, design: genre.bodyFontDesign).weight(.semibold))
                    .foregroundStyle(genre.bookProseColor)
                Text("This usually takes a few seconds.")
                    .font(.caption)
                    .foregroundStyle(genre.bookMetaColor)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .genreBookCard(genre, style: .compact)
    }

    private var headline: String {
        switch genre {
        case .murderMystery: return "Typing up the next page…"
        case .horror:        return "Listening for the next page…"
        case .fantasy:       return "Inking the next page…"
        case .sciFi:         return "Decoding the next page…"
        case .cosyMystery:   return "Pouring the next page…"
        case .adventure:     return "Marking out the next stretch…"
        }
    }
}

/// Surfaces a failed page generation with a Retry button. The most
/// common cause is a transient LLM-proxy hiccup — the previous flow
/// silently swallowed these and left the user staring at an unchanged
/// page wondering if their tap registered.
private struct GenerationErrorBanner: View {
    let genre: StoryGenre
    let message: String
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Space.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(genre.accentColor)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 6) {
                Text(message)
                    .font(.bodyMedium)
                    .foregroundStyle(genre.bookProseColor)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Space.xs) {
                    Button(action: onRetry) {
                        Text("Try again")
                            .font(.caption.weight(.bold))
                            .tracking(1.0)
                            .foregroundStyle(Color.brandTextOnPrimary)
                            .padding(.horizontal, Space.sm)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(genre.accentColor))
                    }
                    .buttonStyle(.plain)
                    Button(action: onDismiss) {
                        Text("Dismiss")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(genre.bookMetaColor)
                            .padding(.horizontal, Space.sm)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .genreBookCard(genre, style: .compact)
    }
}

// MARK: - Header

private struct StoryHeader: View {
    let dog: Dog
    let story: Story?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(dog.name)'s story.")
                .font(.displayLarge)
                .atmosphereTextPrimary()
            if let story {
                HStack(spacing: 6) {
                    Image(systemName: story.genre.symbol)
                        .font(.caption.weight(.semibold))
                    Text(story.genre.displayName.uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(0.5)
                }
                .foregroundStyle(story.genre.accentColor)
                .padding(.horizontal, Space.sm)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(story.genre.accentColor.opacity(0.15))
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Empty state

private struct EmptyStoryPlaceholder: View {
    var body: some View {
        VStack(spacing: Space.md) {
            Image(systemName: "book.closed")
                .font(.system(size: 40))
                .foregroundStyle(Color.brandTextTertiary)
            Text("Add a dog to begin a story.")
                .font(.titleMedium)
                .foregroundStyle(Color.brandTextSecondary)
        }
        .padding(Space.xl)
    }
}
