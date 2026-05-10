#if DEBUG
import Foundation
import SwiftData

/// DEBUG-only StoryService surface for the Profile → Debug Tools card and
/// the matching `trot://debug/story/...` deep links. None of this ships in
/// Release — the file compiles out entirely.
@MainActor
extension StoryService {
    /// Force the active story into its finale immediately. Stamps a
    /// templated title + closing line (no LLM call), moves the story to
    /// `dog.completedStories`, returns the finished `Story` so the
    /// caller can show the finale overlay. No-op if there's no active
    /// story.
    @discardableResult
    static func debugForceFinishActiveStory(
        for dog: Dog,
        in context: ModelContext
    ) -> Story? {
        guard let story = dog.story else { return nil }
        // Find the most recent open chapter (or fall back to the last
        // one). The finale path doesn't write a new chapter — we just
        // need a chapter object to satisfy `finishBook`'s closure on
        // the closed chapter.
        let chapters = (story.chapters ?? []).sorted { $0.index < $1.index }
        let chapterToClose: StoryChapter
        if let open = chapters.last(where: { $0.closedAt == nil }) {
            chapterToClose = open
        } else if let last = chapters.last {
            chapterToClose = last
        } else {
            // Defensive — story exists with no chapters. Make one.
            let placeholder = StoryChapter(index: 1)
            placeholder.story = story
            context.insert(placeholder)
            chapterToClose = placeholder
        }

        // Only stamp closedAt if the chapter is actually open — we
        // don't want to rewrite a real chapter close timestamp.
        if chapterToClose.closedAt == nil {
            chapterToClose.closedAt = .now
            chapterToClose.title = chapterToClose.title.isEmpty
                ? "Chapter \(chapterToClose.index)"
                : chapterToClose.title
            chapterToClose.closingLine = chapterToClose.closingLine.isEmpty
                ? "And so the chapter closes."
                : chapterToClose.closingLine
        }
        chapterToClose.seenAt = chapterToClose.closedAt

        let result = finishBook(
            story: story,
            closingChapter: chapterToClose,
            bookTitle: "\(dog.name)'s \(story.genre.displayName)",
            bookClosingLine: "And there the book closes, for now.",
            dog: dog,
            modelContext: context
        )
        if case .bookFinished(_, let finished) = result {
            return finished
        }
        return nil
    }

    /// Synthesises a fully-formed completed book directly into
    /// `dog.completedStories` without going through any walk gating or
    /// LLM calls. Useful for QA'ing the bookshelf UI without slogging
    /// through 25 walks. Each invocation creates one new finished book
    /// with five chapters of placeholder prose; chapter 1 is marked
    /// seen so no celebration overlay re-fires.
    @discardableResult
    static func debugSeedCompletedBook(
        for dog: Dog,
        genre: StoryGenre = .cosyMystery,
        in context: ModelContext
    ) -> Story {
        let story = Story(genre: genre)
        story.sceneRaw = genre.scenes.first?.id ?? ""
        story.bible = "(debug-seeded book)"
        story.title = "\(dog.name)'s \(genre.displayName)"
        story.closingLine = "And there the book closes, for now."
        story.finishedAt = .now
        context.insert(story)

        for chapterIndex in 1...genre.chaptersPerBook {
            let chapter = StoryChapter(index: chapterIndex)
            chapter.title = "Chapter \(chapterIndex)"
            chapter.closingLine = "And so chapter \(chapterIndex) closed."
            chapter.closedAt = Date(timeIntervalSinceNow: -Double(genre.chaptersPerBook - chapterIndex) * 86400)
            chapter.seenAt = chapter.closedAt
            chapter.story = story
            context.insert(chapter)

            for pageIndex in 1...5 {
                let page = StoryPage(
                    index: pageIndex,
                    globalIndex: (chapterIndex - 1) * 5 + pageIndex
                )
                page.prose = "Placeholder page \(pageIndex) of chapter \(chapterIndex). Lorem ipsum but in \(genre.displayName) flavour."
                page.pathChoiceA = "Placeholder A"
                page.pathChoiceB = "Placeholder B"
                page.userChoice = pageIndex < 5 ? "a" : ""
                page.chapter = chapter
                context.insert(page)
            }
        }

        if dog.completedStories == nil {
            dog.completedStories = [story]
        } else {
            dog.completedStories?.append(story)
        }
        try? context.save()
        return story
    }

    /// Replace the active story's scene with a different one under the
    /// same genre. Used for QA cycling without going through the
    /// scene-picker flow.
    static func debugSwapScene(
        to scene: StoryGenre.Scene,
        for dog: Dog,
        in context: ModelContext
    ) {
        guard let story = dog.story else { return }
        story.sceneRaw = scene.id
        try? context.save()
    }
}
#endif
