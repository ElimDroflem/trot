import Testing
import Foundation
@testable import Trot

@Suite("StoryChapter model")
@MainActor
struct StoryChapterTests {
    /// Tripwire — `seenAt` replaces the legacy UserDefaults seen-state
    /// (which was install-scoped and re-fired the chapter-close overlay
    /// on every reinstall). If the field is removed, the legacy
    /// migrator goes silent and the overlay re-fires on every install.
    @Test("StoryChapter has seenAt field")
    func chapterHasSeenAt() {
        let chapter = StoryChapter(index: 1)
        let names = Set(Mirror(reflecting: chapter).children.compactMap(\.label))
        #expect(names.contains("_seenAt"))
        #expect(names.contains("_closedAt"))
    }

    /// `markChapterSeen` is idempotent — calling twice doesn't move the
    /// timestamp. Caller can safely re-fire (e.g. on view re-render)
    /// without overwriting the original dismiss moment.
    @Test("markChapterSeen is idempotent")
    func markIsIdempotent() {
        let chapter = StoryChapter(index: 1)
        chapter.closedAt = Date(timeIntervalSinceNow: -100)

        StoryService.markChapterSeen(chapter)
        let firstStamp = chapter.seenAt
        #expect(firstStamp != nil)

        StoryService.markChapterSeen(chapter)
        #expect(chapter.seenAt == firstStamp)
    }

    /// `unseenClosedChapter` returns nil when every closed chapter has a
    /// non-nil `seenAt`, regardless of the legacy UserDefaults state.
    @Test("unseenClosedChapter ignores chapters with seenAt set")
    func unseenIgnoresSeen() {
        // Build a dog with a story and a single closed-and-seen chapter.
        // No SwiftData container needed — the service is a pure function
        // over the model graph.
        let dog = Dog(
            name: "Test",
            breedPrimary: "Beagle",
            dateOfBirth: Date(timeIntervalSince1970: 0),
            weightKg: 10,
            sex: .female,
            isNeutered: true
        )
        let story = Story(genre: .cosyMystery)
        dog.story = story
        let chapter = StoryChapter(index: 1)
        chapter.story = story
        chapter.closedAt = Date(timeIntervalSinceNow: -3600)
        chapter.seenAt = chapter.closedAt
        story.chapters = [chapter]

        #expect(StoryService.unseenClosedChapter(for: dog) == nil)
    }
}
