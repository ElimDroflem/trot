#if DEBUG
import Foundation
import SwiftData

/// First-launch demo data for DEBUG builds. Seeds Luna + a 7-day backdrop of
/// walks so every surface (Today ring, Insights, Daily rhythm, Streak, Journey
/// progress, Achievements) has data to say something *real* on the first
/// screenshot — a single seeded walk made averages look broken (one 42-min
/// walk → "averaging 6 min/day").
///
/// Synthetic walks are marked with the `Self.syntheticNotesTag` in `notes` so
/// the Profile → Debug Tools "Wipe synthetic walks" affordance can remove only
/// the seed data without touching real user logs. The tag is intentionally a
/// short bracketed sentinel — it stays out of UI display (notes are blank in
/// the seed) and is trivial to filter on.
enum DebugSeed {
    /// Sentinel written into `Walk.notes` for every synthetic walk. The wipe
    /// affordance filters on this exact prefix; never reuse for real walks.
    static let syntheticNotesTag = "[debug-seed]"

    @MainActor
    static func seedIfEmpty(container: ModelContainer) {
        let context = container.mainContext

        let existing = (try? context.fetchCount(FetchDescriptor<Dog>())) ?? 0
        guard existing == 0 else { return }

        let calendar = Calendar(identifier: .gregorian)
        let dob = calendar.date(byAdding: .year, value: -3, to: .now)
            ?? Date(timeIntervalSince1970: 0)

        let luna = Dog(
            name: "Luna",
            breedPrimary: "Beagle",
            dateOfBirth: dob,
            weightKg: 12,
            sex: .female,
            isNeutered: true,
            activityLevel: .moderate,
            dailyTargetMinutes: 60
        )
        luna.llmRationale = "Beagles do best with a second walk before sundown."

        context.insert(luna)

        let morning = WalkWindow(slot: .earlyMorning, enabled: true, dog: luna)
        let evening = WalkWindow(slot: .evening, enabled: true, dog: luna)
        context.insert(morning)
        context.insert(evening)

        // 6 walks across the past 7 days — one rest day (3 days ago) so the
        // streak is interesting but unbroken (rolling 7-day window allows one
        // rest). Hours mix morning/lunchtime/evening so the Daily Rhythm
        // chart has visible distribution.
        let entries: [(daysAgo: Int, hour: Int, duration: Int)] = [
            (6, 7,  38),   // a week ago, morning
            (5, 18, 50),   // 5 days ago, evening
            (4, 8,  32),   // 4 days ago, morning
            // (3, ...) — rest day
            (2, 12, 25),   // 2 days ago, lunchtime
            (1, 7,  55),   // yesterday, morning
            (0, 8,  35),   // today, morning (clamped to never be in the future)
        ]

        var totalSeededMinutes = 0
        for entry in entries {
            guard let day = calendar.date(byAdding: .day, value: -entry.daysAgo, to: .now) else { continue }
            let dayStart = calendar.startOfDay(for: day)
            let target = calendar.date(bySettingHour: entry.hour, minute: 0, second: 0, of: dayStart) ?? dayStart
            // Today's morning walk would land in the future for an early-AM
            // launch — clamp to "1 minute ago" so we never produce a future
            // walk (DatePicker rejects them on edit, and streak math gets
            // confused).
            let oneMinuteAgo = Date.now.addingTimeInterval(-60)
            let walkStart = min(target, oneMinuteAgo)

            let walk = Walk(
                startedAt: walkStart,
                durationMinutes: entry.duration,
                distanceMeters: estimatedDistance(forMinutes: entry.duration),
                source: .passive,
                notes: syntheticNotesTag,
                dogs: [luna]
            )
            context.insert(walk)
            totalSeededMinutes += entry.duration
        }

        // Apply the lifetime seed minutes to Luna's active route so the
        // Journey tab reflects the same walk history as Today/Insights.
        // Without this, route progress stays at zero while Highlights happily
        // shows "6 walks · 3h 55m" — the data inconsistency the user reported.
        // We don't keep the WalkApplication result — landmark celebrations
        // belong to real walks, not lived-in seed.
        _ = JourneyService.applyWalk(minutes: totalSeededMinutes, to: luna)

        // Seed Luna's story so the Story tab opens to a populated state in
        // DEBUG without burning real LLM calls. Picks Murder Mystery (most
        // visually distinct theme — noir + smoke), seeds one closed
        // chapter for the shelf, and an active chapter at page 3 of 5 so
        // the spine shows past+current+future cleanly.
        // -DebugSkipStorySeed YES leaves Luna with no story so the genre
        // picker appears on the Story tab — used to QA the picker UI.
        if !UserDefaults.standard.bool(forKey: "DebugSkipStorySeed") {
            seedStory(for: luna, in: context)
        }

        // Pre-mark milestones the seed walks already satisfy so the user
        // doesn't see "Luna's first walk" overlay every fresh debug install
        // — Luna here is a lived-in dog with a 6-walk history, not a
        // brand-new pup. Real first-time users hit these celebrations the
        // honest way (logging their first walk).
        let preFired: [MilestoneCode] = [
            .firstWalk,
            .firstHalfTargetDay,
            .firstFullTargetDay,  // covered by 50-min walk vs 60-min target
            .first100LifetimeMinutes,
            .first3DayStreak,
            .firstWeek,
        ]
        luna.firedMilestones = preFired.map(\.rawValue)

        do {
            try context.save()
        } catch {
            print("DebugSeed save failed: \(error)")
        }
    }

    /// Removes every synthetic walk from the store (filtered by the
    /// `syntheticNotesTag` sentinel). Leaves real user-logged walks alone.
    /// Returns the number deleted so the caller can report it.
    @MainActor
    @discardableResult
    static func wipeSyntheticWalks(in context: ModelContext) -> Int {
        // The #Predicate macro can't reference a static let on a non-Model
        // type, so capture the tag in a local first.
        let tag = syntheticNotesTag
        let predicate = #Predicate<Walk> { $0.notes == tag }
        let descriptor = FetchDescriptor<Walk>(predicate: predicate)
        let synthetic = (try? context.fetch(descriptor)) ?? []
        for walk in synthetic { context.delete(walk) }
        try? context.save()
        return synthetic.count
    }

    /// Counts synthetic walks for the Debug Tools card banner.
    @MainActor
    static func syntheticWalkCount(in context: ModelContext) -> Int {
        let tag = syntheticNotesTag
        let predicate = #Predicate<Walk> { $0.notes == tag }
        let descriptor = FetchDescriptor<Walk>(predicate: predicate)
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    /// Rough pedometer-style distance estimate so the seed walks have non-nil
    /// distance values (the Activity tab and lifetime totals look bare without
    /// them). ~70 m/min average walking pace. Real walks come from HealthKit's
    /// `distanceWalkingRunning` which is materially more accurate.
    private static func estimatedDistance(forMinutes minutes: Int) -> Double {
        Double(minutes) * 70.0
    }

    @MainActor
    private static func seedStory(for dog: Dog, in context: ModelContext) {
        let story = Story(genre: .murderMystery)
        story.bible = """
            Setting: Hookwood, a small village in the South Downs. Summer.
            Characters: Luna (Beagle, food-driven, scent-led, owner-curious). \
            The narrator (Luna's owner). Mr Pell, the postman who's been \
            acting strangely. Mrs Daunt, the WI chair who saw something at \
            the village hall. Open thread: someone took the trophy from \
            the Hookwood horticultural show. Luna sniffed the empty plinth \
            and barked twice — she might know more than she's letting on.
            """
        dog.story = story
        context.insert(story)

        // Closed chapter 1 — appears in the chapters shelf.
        let chapter1 = StoryChapter(index: 1)
        chapter1.title = "The Empty Plinth"
        chapter1.closingLine = "And then Luna sneezed, definitively, on a clue she didn't yet understand."
        chapter1.closedAt = Date(timeIntervalSinceNow: -7 * 24 * 3600)
        chapter1.story = story
        context.insert(chapter1)

        let c1Pages = [
            ("The horticultural show was over by four. The trophy was gone by five. Luna found me at the edge of the marquee, ear cocked, doing her best impression of someone who hadn't already been near it.",
             "Try the empty plinth", "Look outside the marquee"),
            ("The plinth smelled of polish and biscuit. Luna's nose hovered an inch from it, methodical, as if reading a letter she'd been sent. Mr Pell stood by the entrance, redirecting children. He didn't look up when I came in.",
             "Confront Mr Pell", "Follow Luna's nose"),
            ("Mrs Daunt found me by the bins. \"It was already gone,\" she said, in the way people say things they want to be true. \"Before three.\" Luna sat between us, head down, chewing nothing.",
             "Press Mrs Daunt", "Walk Luna home"),
            ("On the path home, Luna stopped at a hedge that hadn't interested her this morning. She stared. She made the small huff she makes when she's doing maths.",
             "Look in the hedge", "Carry on home"),
            ("Inside the hedge, snagged on a thorn, was a length of green ribbon — the same green that had been tied around the trophy. Luna sneezed, twice, with feeling.",
             "Tell the WI", "Save the ribbon"),
        ]
        for (i, entry) in c1Pages.enumerated() {
            let page = StoryPage(index: i + 1, globalIndex: i + 1)
            page.prose = entry.0
            page.pathChoiceA = entry.1
            page.pathChoiceB = entry.2
            page.userChoice = i < 4 ? "a" : ""
            page.chapter = chapter1
            context.insert(page)
        }

        // Active chapter 2 — three pages so the spine shows a clean
        // past/current/future spread. Page 3 is "current" with no choice
        // committed yet; pageReady state will offer its two paths.
        let chapter2 = StoryChapter(index: 2)
        chapter2.story = story
        context.insert(chapter2)

        let c2Pages = [
            ("Chapter 2 opened on a Tuesday and Luna disapproved. The post hadn't come. Mr Pell's bicycle was leaning against the wrong gate, which was a thing in a village where bicycles meant biographies.",
             "Knock on Mr Pell's door", "Ask about the bicycle"),
            ("Mr Pell's window was open. Inside, faintly, a kettle. Luna pointed her nose at the door like a witness who'd already given evidence and didn't want to be asked again. The bicycle's basket was empty except for a single green thread.",
             "Pick up the thread", "Walk on, return later"),
            ("I crouched. Luna crouched. The thread caught the light. Behind us, somewhere, a back door clicked shut.",
             "Turn and look", "Stay still and listen"),
        ]
        for (i, entry) in c2Pages.enumerated() {
            let page = StoryPage(index: i + 1, globalIndex: 5 + i + 1)
            page.prose = entry.0
            page.pathChoiceA = entry.1
            page.pathChoiceB = entry.2
            // Pages 1-2 have user choices recorded; page 3 is "current" with no
            // choice yet, so the user can pick a path on screen.
            page.userChoice = i < 2 ? "a" : ""
            // Stamp the latest page in the past so today's walks + no page
            // today triggers the pageReady state (path-choice UI). Without
            // this, the seed would land on caughtUp because every page is
            // created at seed-time = today.
            let daysAgo = (c2Pages.count - i)
            page.createdAt = Date().addingTimeInterval(-Double(daysAgo) * 24 * 3600)
            page.chapter = chapter2
            context.insert(page)
        }

        // Save first so persistentModelIDs are stable before we use them
        // as UserDefaults keys.
        try? context.save()

        // Mark chapter 1 as already seen so the celebration overlay doesn't
        // pop on every fresh seed install — the user is in the middle of
        // chapter 2, not just finishing 1.
        UserDefaults.standard.set(true, forKey: "trot.story.chapterSeen.\(chapter1.persistentModelID.hashValue)")
    }
}
#endif
