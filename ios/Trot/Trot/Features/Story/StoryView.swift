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

    private var selectedDog: Dog? { appState.selectedDog(from: activeDogs) }

    var body: some View {
        let genre = selectedDog?.story?.genre

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
                dismissedCelebrationIDs.insert(ref.chapter.persistentModelID)
                celebrationChapter = nil
            }
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
            let state = StoryService.currentState(for: dog)
            switch state {
            case .noStory:
                StoryGenrePicker { genre in
                    Task { await pickGenre(genre, for: dog) }
                }
            case .awaitingFirstWalk(let page):
                ScrollView {
                    VStack(spacing: Space.lg) {
                        StoryHeader(dog: dog, story: dog.story)
                        StoryPageReader(
                            dog: dog,
                            page: page,
                            interaction: .awaitingWalk
                        )
                        chapterShelf(dog: dog)
                        Color.clear.frame(height: Space.lg)
                    }
                    .padding(.horizontal, Space.md)
                    .padding(.top, Space.md)
                }
            case .pageReady(let page), .caughtUp(let page):
                ScrollView {
                    VStack(spacing: Space.lg) {
                        StoryHeader(dog: dog, story: dog.story)
                        ChapterSpine(
                            chapter: dog.story?.currentChapter,
                            currentPage: page,
                            genre: dog.story?.genre ?? .adventure
                        )
                        StoryPageReader(
                            dog: dog,
                            page: page,
                            interaction: state.isPageReady
                                ? .pickPath { choice, text, photo in
                                    Task {
                                        await generateNext(
                                            for: dog,
                                            choice: choice,
                                            text: text,
                                            photo: photo
                                        )
                                    }
                                }
                                : .caughtUp
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
                            StoryPageReader(dog: dog, page: page, interaction: .caughtUp)
                            chapterShelf(dog: dog)
                            Color.clear.frame(height: Space.lg)
                        }
                        .padding(.horizontal, Space.md)
                        .padding(.top, Space.md)
                    }
                }
            }
        } else {
            EmptyStoryPlaceholder()
        }
    }

    private func chapterShelf(dog: Dog) -> some View {
        StoryChapterShelf(
            dog: dog,
            genre: dog.story?.genre ?? .adventure,
            onTap: { readingChapter = ChapterRef(chapter: $0) }
        )
    }

    // MARK: - Actions

    private func pickGenre(_ genre: StoryGenre, for dog: Dog) async {
        _ = await StoryService.pickGenre(genre, for: dog, modelContext: modelContext)
        await MainActor.run { refreshTick &+= 1 }
    }

    private func generateNext(
        for dog: Dog,
        choice: String,
        text: String,
        photo: Data?
    ) async {
        _ = await StoryService.generateNextPage(
            for: dog,
            userChoice: choice,
            userText: text,
            imageJPEG: photo,
            modelContext: modelContext
        )
        await MainActor.run { refreshTick &+= 1 }
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

// MARK: - Helpers

private extension StoryService.State {
    var isPageReady: Bool {
        if case .pageReady = self { return true }
        return false
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
