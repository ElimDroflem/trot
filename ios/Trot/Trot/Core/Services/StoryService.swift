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
        case caughtUp(latestPage: StoryPage, lock: PageLock)
        case chapterClosed(closedChapter: StoryChapter, prologuePage: StoryPage)
    }

    /// Why the user can't advance from `caughtUp` right now. Drives the
    /// copy under the (still-visible but disabled) path-choice buttons.
    enum PageLock: Equatable {
        /// User has walked today but not yet hit the milestone needed
        /// for the next page. `minutesNeeded` is what's left to walk.
        case needMoreMinutes(minutesNeeded: Int, milestone: Milestone)
        /// User has already generated both of today's pages — cap is two
        /// per local day. Resets at the next local midnight.
        case dailyCapHit
    }

    /// Two milestones gate the day's two pages. Page 1 unlocks at half
    /// the dog's daily target, page 2 at the full target. Anti-grind:
    /// regardless of how many walks the user logs, they cannot exceed
    /// two pages in a calendar day.
    enum Milestone {
        case halfTarget
        case fullTarget
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

        // Walks today + cumulative minutes. Drives milestone checks.
        let walksToday = (dog.walks ?? []).filter {
            calendar.isDate($0.startedAt, inSameDayAs: now)
        }
        let minutesToday = walksToday.reduce(0) { $0 + $1.durationMinutes }
        let everWalked = !(dog.walks ?? []).isEmpty

        // Pages already generated today across the whole story. Anti-
        // grind cap is 2 per local day regardless of how many walks the
        // user logs.
        let pagesGeneratedToday = allPages.filter {
            calendar.isDate($0.createdAt, inSameDayAs: now)
        }.count

        // Daily target + the two milestone thresholds. `dailyTargetMinutes`
        // is per-dog and editable, so the gate adapts to the actual
        // exercise need (60 min beagle vs 90 min collie etc.).
        let target = max(1, dog.dailyTargetMinutes)
        let halfTarget = max(1, target / 2)

        // Pre-walk: never walked at all. Show the prologue with a calm
        // "first walk unlocks page 2" pull, no decisions panel.
        if !everWalked {
            return .awaitingFirstWalk(latestPage: latest)
        }

        // Daily cap hit — both of today's pages already generated. Lock
        // out for the rest of the day. The UI reads this as "Two pages
        // today, the rest is for tomorrow."
        if pagesGeneratedToday >= 2 {
            return .caughtUp(latestPage: latest, lock: .dailyCapHit)
        }

        // Which milestone unlocks the *next* page. If no pages today
        // yet, the half-target unlocks page 1; if one page has been
        // generated, the full target unlocks page 2.
        let nextMilestone: Milestone = pagesGeneratedToday == 0 ? .halfTarget : .fullTarget
        let neededMinutes = nextMilestone == .halfTarget ? halfTarget : target

        if minutesToday >= neededMinutes {
            return .pageReady(latestPage: latest)
        }

        let minutesNeeded = max(1, neededMinutes - minutesToday)
        return .caughtUp(
            latestPage: latest,
            lock: .needMoreMinutes(minutesNeeded: minutesNeeded, milestone: nextMilestone)
        )
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

    /// User picked a genre + scene. Creates the Story (persisting the
    /// scene id BEFORE the LLM call so the fallback / rolling bible
    /// inherit it), the first chapter, and fires the LLM to write the
    /// prologue page (no walk facts — genre + scene + dog profile alone).
    /// On LLM failure, persists a templated prologue so the UI never
    /// sits empty.
    @discardableResult
    static func pickGenre(
        _ genre: StoryGenre,
        scene: StoryGenre.Scene,
        for dog: Dog,
        modelContext: ModelContext
    ) async -> GenerationResult {
        let story = Story(genre: genre)
        story.sceneRaw = scene.id
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

        let payload = await LLMService.storyPage(
            for: dog,
            genre: genre,
            scene: story.scene,
            ownerName: ownerName,
            bible: story.bible,
            previousPages: previousPages,
            walkFacts: walkFacts,
            userChoice: userChoice,
            userText: userText,
            pageIndexInChapter: nextIndex,
            isPrologue: isPrologue,
            imageJPEG: imageJPEG
        )

        // For the prologue specifically we MUST persist a page even on
        // LLM failure — `currentState(for:)` interprets a story with zero
        // pages as `.noStory`, which silently drops the user back on the
        // genre picker after they tapped Begin. Falling back to a
        // templated prologue keeps them on the book.
        let resolvedPayload: LLMService.StoryPagePayload
        if let payload {
            resolvedPayload = payload
        } else if isPrologue {
            resolvedPayload = fallbackPrologue(for: dog, genre: genre)
        } else {
            return .failed("Couldn't reach the storyteller. Try again.")
        }

        let page = StoryPage(index: nextIndex, globalIndex: nextGlobalIndex)
        page.prose = resolvedPayload.prose
        page.pathChoiceA = resolvedPayload.choiceA
        page.pathChoiceB = resolvedPayload.choiceB
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

    /// Templated prologue used when the LLM is unreachable on the very
    /// first page. Each entry is ~160 words, 2-3 paragraphs, sized to
    /// fit one iPhone screen at body font. Channelled author voices —
    /// Christie, King, Martin, Herbert, Osman, Macfarlane — so the
    /// offline experience is recognisably the chosen book. The next
    /// walk's page will be LLM-generated; this fallback only ever
    /// shows on a connectivity-poor first launch.
    private static func fallbackPrologue(
        for dog: Dog,
        genre: StoryGenre
    ) -> LLMService.StoryPagePayload {
        let dogName = dog.name.isEmpty ? "the dog" : dog.name
        let breed = dog.breedPrimary.isEmpty ? "dog" : dog.breedPrimary.lowercased()
        let prose: String
        let choiceA: String
        let choiceB: String
        switch genre {
        case .murderMystery: // Channelling Agatha Christie.
            prose = """
            It began, as these things so often do, at the village hall on a Tuesday. The bunting was up for the horticultural show, the urn had been on since nine, and the Reverend Halliday was telling Mrs Padbury about his runner beans, who did not care for them in the slightest and was nodding at exactly the right moments.

            \(dogName), the \(breed), cared for a smell coming from beneath the trestle table at the back of the hall. A smell that ought not to have been there.

            By the time the trophy was missed, three people had lied without meaning to and one had lied on purpose. \(dogName) had positioned itself between the side door and the tea urn, in the way of a creature that had decided to be a witness.
            """
            choiceA = "Slip out the side door"
            choiceB = "Stay near the trestle"
        case .horror: // Channelling Stephen King.
            prose = """
            The cul-de-sac had been quiet since Tuesday. Not the ordinary quiet of a place where people kept their televisions low, but the other kind — the kind where the wood pigeons stopped halfway through a call and forgot to start again.

            \(dogName) wouldn't go past the third lamp post. The \(breed) sat down on the wet pavement and looked at me the way dogs look at people when they are trying very hard not to say I told you so. The lamp at the end of the road had been on since yesterday afternoon. Lamps weren't supposed to be on at four o'clock.

            Up in the house at the bend, a curtain that had been still all morning twitched once. Not a draught twitch. A held-breath twitch.
            """
            choiceA = "Walk past the lamp post"
            choiceB = "Turn around and head home"
        case .fantasy: // Channelling George RR Martin.
            prose = """
            The bell at St Cuthwine's rang seven and stopped, which was wrong. It should have rung eight. The man who pulled the rope was old and reliable and not given to mistakes, which meant the bell itself had decided. Bells, in this part of the country, were allowed to decide.

            \(dogName) heard it before I did. The \(breed) had been asleep on the flagstones, one ear back, and now both ears were forward. Not afraid. Listening. There is a difference, and any dog will teach you that difference if you watch them long enough.

            The lane to the river was older than the village. \(dogName) stood up, shook off, and looked at the door.
            """
            choiceA = "Take the lane to the river"
            choiceB = "Go up to the church first"
        case .sciFi: // Channelling Frank Herbert (Dune).
            prose = """
            Three nights running, the dish on the next farm had turned itself to a corner of the sky where there was nothing to receive. Each evening I had told myself it was the wind. There had been no wind.

            \(dogName) knew before I did. The \(breed) had stopped going into the back garden after dark on the second night, and now sat at the threshold with the patient, attentive stillness of an animal listening to a frequency I could not name.

            At seven minutes to four the kitchen radio cut out for the length of one held breath and resumed mid-word. \(dogName) stood, shook himself once, and walked to the front door. He did not look back to see if I was following.
            """
            choiceA = "Follow the dog out the front"
            choiceB = "Stay inside, watch the dish"
        case .cosyMystery: // Channelling Richard Osman.
            prose = """
            The trouble started, as trouble in our village invariably does, at the WI summer fête. The lemon drizzle had sold out by ten past two. The egg-and-spoon had been cancelled because of the egg shortage, which is a sentence I never expected to write.

            \(dogName) was, of course, in attendance. A \(breed) at a village fête is approximately as inconspicuous as a brass band, and \(dogName) had been working the back of the cake stall with the quiet persistence of a small, food-motivated detective.

            Then \(dogName) sniffed a handbag belonging to a woman who hadn't arrived, sat down beside it, and refused to move. "Right," said Mrs Daunt, in the voice she uses for matters of consequence. "Whose is that?"
            """
            choiceA = "Wait with the dog and the bag"
            choiceB = "Go and find Mrs Daunt"
        case .adventure: // Channelling Robert Macfarlane.
            prose = """
            The morning came in cold off the moor, the kind of cold that smells faintly of stone. There had been rain in the night and the lane was running, a thin braid of water down the chalk, finding the camber the road builders had set there a hundred and forty years ago and forgotten.

            \(dogName) was already at the door. The \(breed) had its own opinions about mornings — chiefly, that they were happening, and that they ought to be moving.

            Above the village the mist had settled in the high coombe, lying along the flank of the hill the way an animal lies along a wall. We had a choice this morning, \(dogName) and I. Neither of us had decided yet. The decision, I suspected, would be the dog's.
            """
            choiceA = "Take the high path"
            choiceB = "Take the river path"
        }
        return LLMService.StoryPagePayload(prose: prose, choiceA: choiceA, choiceB: choiceB)
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
