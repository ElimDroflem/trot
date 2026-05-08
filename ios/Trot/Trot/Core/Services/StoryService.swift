import Foundation
import SwiftData

/// Orchestrates the per-dog narrative. Owns the full state machine for
/// generating pages, closing chapters, and persisting everything to
/// SwiftData. UI never calls the LLM directly — it asks the service for
/// the current state, gets a result, and renders it.
///
/// State machine (per dog):
///   - **noStory** → user hasn't picked a genre yet. UI shows the picker.
///   - **awaitingFirstWalk** → genre picked, prologue written, but no
///       walk has happened yet. UI shows the prologue + a waiting card.
///   - **pageReady** → walks happened today and no page has been
///       generated for today yet. UI shows the previous page's two-path
///       buttons + write/photo affordances.
///   - **caughtUp** → today's page already exists. UI shows the latest
///       page in the reader.
///   - **chapterClosed** → the just-generated page closed a chapter and
///       the close LLM call has run. UI shows the celebration takeover.
///
/// Generation rules:
///   - One page per dog per local calendar day. Prevents a long-walk
///     splat or multiple-walks-per-day producing incoherent prose.
///   - Page 1 of chapter 1 is the prologue — generated immediately when
///     the user picks a genre, no walk facts. Pages 2+ use walk facts.
///   - Page 5 closes the chapter. The close call generates the title +
///     closing line + new bible + prologue page of chapter N+1.
///
/// Failure mode: every LLM call returns nil on failure; the service
/// returns a `.failed(reason:)` result so the UI can show a retry. State
/// stays consistent — we only persist after a successful response.
@MainActor
enum StoryService {
    enum State {
        case noStory
        case awaitingFirstWalk(latestPage: StoryPage)
        case pageReady(latestPage: StoryPage)
        case caughtUp(latestPage: StoryPage)
        case chapterClosed(closedChapter: StoryChapter, prologuePage: StoryPage)
    }

    /// Result of an attempted generation — either the new page (or close
    /// outcome) or a failure description for the UI to surface.
    enum GenerationResult {
        case page(StoryPage)
        case chapterClosed(closedChapter: StoryChapter, newChapter: StoryChapter, prologue: StoryPage)
        case failed(String)
    }

    // MARK: - State queries

    static func currentState(
        for dog: Dog,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> State {
        guard let story = dog.story else { return .noStory }

        // Find the most recent page across the whole story (latest globalIndex).
        let allPages = (story.chapters ?? []).flatMap { $0.pages ?? [] }
        guard let latest = allPages.max(by: { $0.globalIndex < $1.globalIndex }) else {
            // Story exists but no pages — shouldn't happen because we
            // always seed a prologue at picker-time, but treat defensively
            // as a no-walk state.
            return .noStory
        }

        // Has a chapter just closed? `chapterClosed` is technically a
        // transient state — the close already wrote the prologue of the
        // next chapter, so the latest page IS the new prologue. We
        // detect "just closed" by: user is on the prologue page of a
        // chapter (index 1) AND a previous chapter has a non-empty title.
        // The UI consumes this state once via a flag (see
        // `consumeChapterClosedFlag`).

        let walksToday = (dog.walks ?? []).filter {
            calendar.isDate($0.startedAt, inSameDayAs: now)
        }
        let hasWalkToday = !walksToday.isEmpty
        let pageWrittenToday = calendar.isDate(latest.createdAt, inSameDayAs: now)

        if !hasWalkToday {
            // No walks today; the latest page is whatever it was. If it's
            // the prologue (globalIndex == 1) and there are zero walks
            // ever, we're in the awaitingFirstWalk state.
            let everWalked = !(dog.walks ?? []).isEmpty
            if !everWalked {
                return .awaitingFirstWalk(latestPage: latest)
            }
            // Walks have happened in the past but not today. The user
            // could still generate a page for "today" once they walk; for
            // now show the caught-up reader so they re-read recent pages.
            return .caughtUp(latestPage: latest)
        }

        if pageWrittenToday {
            return .caughtUp(latestPage: latest)
        }
        return .pageReady(latestPage: latest)
    }

    /// True if the latest page closed a chapter that hasn't been "seen"
    /// by the user yet — used by the UI to surface the celebration once.
    /// Persistence: a chapter is "seen" once the user has tapped through
    /// the celebration; we mark it via a per-chapter UserDefaults flag.
    static func unseenClosedChapter(for dog: Dog) -> StoryChapter? {
        let chapters = (dog.story?.chapters ?? []).sorted { $0.index < $1.index }
        guard let mostRecentClosed = chapters.last(where: { $0.closedAt != nil }) else {
            return nil
        }
        // Only surface if this is the most recent close AND the next
        // chapter is the active open one (i.e. we're on its prologue).
        let key = seenKey(for: mostRecentClosed)
        if UserDefaults.standard.bool(forKey: key) { return nil }
        return mostRecentClosed
    }

    static func markChapterSeen(_ chapter: StoryChapter) {
        UserDefaults.standard.set(true, forKey: seenKey(for: chapter))
    }

    private static func seenKey(for chapter: StoryChapter) -> String {
        "trot.story.chapterSeen.\(chapter.persistentModelID.hashValue)"
    }

    // MARK: - Genre pick + prologue

    /// User picked a genre. Creates the Story, the first chapter, and
    /// fires the LLM to write the prologue page (no walk facts — genre +
    /// dog profile alone). On LLM failure, persists a templated prologue
    /// so the UI never sits empty.
    @discardableResult
    static func pickGenre(
        _ genre: StoryGenre,
        for dog: Dog,
        modelContext: ModelContext
    ) async -> GenerationResult {
        let story = Story(genre: genre)
        dog.story = story
        modelContext.insert(story)
        let chapter = StoryChapter(index: 1)
        chapter.story = story
        modelContext.insert(chapter)
        try? modelContext.save()

        return await generatePage(
            for: dog,
            chapter: chapter,
            isPrologue: true,
            userChoice: "",
            userText: "",
            imageJPEG: nil,
            modelContext: modelContext
        )
    }

    // MARK: - Page generation

    /// Generates the next page given the user's input on the current
    /// (latest) page. The latest page must be the most recent in the
    /// open chapter — `userChoice/Text/photo` get RECORDED on it, then
    /// the new page is appended.
    @discardableResult
    static func generateNextPage(
        for dog: Dog,
        userChoice: String,
        userText: String,
        imageJPEG: Data?,
        now: Date = .now,
        modelContext: ModelContext
    ) async -> GenerationResult {
        guard let story = dog.story, let chapter = story.currentChapter else {
            return .failed("Story not initialised")
        }

        // Record the user's choice on the latest page so the LLM can
        // read it on the next call AND so we have an audit trail.
        if let latest = chapter.orderedPages.last {
            latest.userChoice = userChoice
            latest.userText = userText
            latest.photo = imageJPEG
            try? modelContext.save()
        }

        return await generatePage(
            for: dog,
            chapter: chapter,
            isPrologue: false,
            userChoice: userChoice,
            userText: userText,
            imageJPEG: imageJPEG,
            modelContext: modelContext
        )
    }

    private static func generatePage(
        for dog: Dog,
        chapter: StoryChapter,
        isPrologue: Bool,
        userChoice: String,
        userText: String,
        imageJPEG: Data?,
        modelContext: ModelContext
    ) async -> GenerationResult {
        guard let story = dog.story else { return .failed("No story") }
        let genre = story.genre
        let ownerName = UserPreferences.ownerName

        // The page index inside this chapter is 1-based: 1 for prologue,
        // up to 5 for the chapter-close trigger.
        let nextIndex = (chapter.pages?.count ?? 0) + 1
        let nextGlobalIndex = (story.chapters ?? [])
            .flatMap { $0.pages ?? [] }
            .map(\.globalIndex)
            .max().map { $0 + 1 } ?? 1

        let walkFacts = isPrologue
            ? "(prologue — no walk facts yet)"
            : walkFactsString(for: dog)

        let previousPages = chapter.orderedPages
            .suffix(2)
            .map(\.prose)
            .joined(separator: "\n\n")

        guard let payload = await LLMService.storyPage(
            for: dog,
            genre: genre,
            ownerName: ownerName,
            bible: story.bible,
            previousPages: previousPages,
            walkFacts: walkFacts,
            userChoice: userChoice,
            userText: userText,
            pageIndexInChapter: nextIndex,
            isPrologue: isPrologue,
            imageJPEG: imageJPEG
        ) else {
            return .failed("Couldn't reach the storyteller. Try again.")
        }

        let page = StoryPage(index: nextIndex, globalIndex: nextGlobalIndex)
        page.prose = payload.prose
        page.pathChoiceA = payload.choiceA
        page.pathChoiceB = payload.choiceB
        page.chapter = chapter
        modelContext.insert(page)
        try? modelContext.save()

        // Page 5 closes the chapter. Fire the close call, persist title +
        // closing + bible, open the next chapter with its prologue.
        if nextIndex >= 5 {
            return await closeChapter(
                story: story,
                closingChapter: chapter,
                modelContext: modelContext
            )
        }

        return .page(page)
    }

    // MARK: - Chapter close

    private static func closeChapter(
        story: Story,
        closingChapter: StoryChapter,
        modelContext: ModelContext
    ) async -> GenerationResult {
        guard let dog = closingChapter.findDog(in: modelContext) ?? findDog(forStory: story, in: modelContext) else {
            return .failed("Could not find dog")
        }
        let genre = story.genre
        let ownerName = UserPreferences.ownerName

        let chapterPagesText = closingChapter.orderedPages
            .map { "Page \($0.index): \($0.prose)" }
            .joined(separator: "\n\n")

        guard let payload = await LLMService.storyChapterClose(
            for: dog,
            genre: genre,
            ownerName: ownerName,
            bible: story.bible,
            chapterPages: chapterPagesText,
            chapterIndex: closingChapter.index
        ) else {
            // Don't fail the whole user action — we already saved page 5.
            // Fall back to a templated close so the chapter still wraps.
            return fallbackClose(
                story: story,
                closingChapter: closingChapter,
                modelContext: modelContext
            )
        }

        // Persist the close on the just-finished chapter.
        closingChapter.title = payload.title
        closingChapter.closingLine = payload.closingLine
        closingChapter.closedAt = .now

        // Roll the bible forward.
        story.bible = payload.bibleUpdate

        // Open the next chapter with its prologue page.
        let nextChapter = StoryChapter(index: closingChapter.index + 1)
        nextChapter.story = story
        modelContext.insert(nextChapter)

        let prologueGlobalIndex = (story.chapters ?? [])
            .flatMap { $0.pages ?? [] }
            .map(\.globalIndex)
            .max().map { $0 + 1 } ?? 1
        let prologue = StoryPage(index: 1, globalIndex: prologueGlobalIndex)
        prologue.prose = payload.prologueProse
        prologue.pathChoiceA = payload.choiceA
        prologue.pathChoiceB = payload.choiceB
        prologue.chapter = nextChapter
        modelContext.insert(prologue)

        try? modelContext.save()
        return .chapterClosed(
            closedChapter: closingChapter,
            newChapter: nextChapter,
            prologue: prologue
        )
    }

    private static func fallbackClose(
        story: Story,
        closingChapter: StoryChapter,
        modelContext: ModelContext
    ) -> GenerationResult {
        closingChapter.title = "Chapter \(closingChapter.index)"
        closingChapter.closingLine = "And so the chapter closes — for now."
        closingChapter.closedAt = .now

        // Open chapter N+1 with a placeholder prologue so the user can
        // still continue reading. The LLM can be retried by the user
        // pulling to refresh in v1.x.
        let nextChapter = StoryChapter(index: closingChapter.index + 1)
        nextChapter.story = story
        modelContext.insert(nextChapter)

        let prologueGlobalIndex = (story.chapters ?? [])
            .flatMap { $0.pages ?? [] }
            .map(\.globalIndex)
            .max().map { $0 + 1 } ?? 1
        let prologue = StoryPage(index: 1, globalIndex: prologueGlobalIndex)
        prologue.prose = "The next chapter opens. (The storyteller will catch up shortly.)"
        prologue.pathChoiceA = "Walk on"
        prologue.pathChoiceB = "Wait and watch"
        prologue.chapter = nextChapter
        modelContext.insert(prologue)
        try? modelContext.save()

        return .chapterClosed(
            closedChapter: closingChapter,
            newChapter: nextChapter,
            prologue: prologue
        )
    }

    // MARK: - Helpers

    private static func findDog(forStory story: Story, in context: ModelContext) -> Dog? {
        let descriptor = FetchDescriptor<Dog>()
        let dogs = (try? context.fetch(descriptor)) ?? []
        return dogs.first { $0.story?.persistentModelID == story.persistentModelID }
    }

    private static func walkFactsString(for dog: Dog) -> String {
        let calendar = Calendar.current
        let today = (dog.walks ?? []).filter {
            calendar.isDateInToday($0.startedAt)
        }.sorted { $0.startedAt < $1.startedAt }
        guard !today.isEmpty else {
            return "(no walks logged today)"
        }
        let totalMin = today.reduce(0) { $0 + $1.durationMinutes }
        let totalKm = today.reduce(0.0) { acc, walk in
            acc + (walk.distanceMeters ?? Double(walk.durationMinutes) * 70.0) / 1000.0
        }
        let kmString = totalKm >= 1 ? String(format: "%.1f km", totalKm) : "\(Int(totalKm * 1000)) metres"

        if today.count == 1 {
            let walk = today[0]
            let label = timeOfDayLabel(for: walk.startedAt, calendar: calendar)
            return "A \(walk.durationMinutes)-minute walk \(label), \(kmString)."
        }
        let parts = today.map { walk -> String in
            "\(walk.durationMinutes) min \(timeOfDayLabel(for: walk.startedAt, calendar: calendar))"
        }.joined(separator: " and ")
        return "Walks today: \(parts). \(totalMin) minutes total, \(kmString)."
    }

    private static func timeOfDayLabel(for date: Date, calendar: Calendar) -> String {
        switch calendar.component(.hour, from: date) {
        case 5..<11:  return "in the morning"
        case 11..<14: return "around lunchtime"
        case 14..<17: return "in the afternoon"
        case 17..<21: return "in the evening"
        default:      return "at night"
        }
    }
}

// Tiny helper used by closeChapter to find the dog from the chapter side.
// SwiftData doesn't auto-back-ref through transitive relationships, so we
// fetch via context if the cheap path is nil.
private extension StoryChapter {
    func findDog(in context: ModelContext) -> Dog? {
        let descriptor = FetchDescriptor<Dog>()
        let dogs = (try? context.fetch(descriptor)) ?? []
        return dogs.first { $0.story?.persistentModelID == self.story?.persistentModelID }
    }
}
