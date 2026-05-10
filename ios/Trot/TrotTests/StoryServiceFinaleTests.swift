import Testing
import Foundation
import SwiftData
@testable import Trot

@Suite("StoryService finale")
@MainActor
struct StoryServiceFinaleTests {
    /// In-memory container so each test starts from a clean store.
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: TrotSchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeDog(in context: ModelContext) -> Dog {
        let dog = Dog(
            name: "Bonnie",
            breedPrimary: "Beagle",
            dateOfBirth: Date(timeIntervalSince1970: 0),
            weightKg: 10,
            sex: .female,
            isNeutered: true
        )
        context.insert(dog)
        return dog
    }

    private func makeActiveStory(for dog: Dog, in context: ModelContext) -> (Story, StoryChapter) {
        let story = Story(genre: .cosyMystery)
        story.sceneRaw = "village"
        dog.story = story
        context.insert(story)
        let chapter = StoryChapter(index: 5)  // FINAL chapter
        chapter.story = story
        context.insert(chapter)
        return (story, chapter)
    }

    @Test("finishBook stamps title, closingLine, finishedAt")
    func finishStampsFields() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let dog = makeDog(in: context)
        let (story, chapter) = makeActiveStory(for: dog, in: context)
        try context.save()

        let result = StoryService.finishBook(
            story: story,
            closingChapter: chapter,
            bookTitle: "The Empty Plinth",
            bookClosingLine: "And so the village swallowed its secret again.",
            dog: dog,
            modelContext: context
        )

        #expect(story.finishedAt != nil)
        #expect(story.title == "The Empty Plinth")
        #expect(story.closingLine == "And so the village swallowed its secret again.")

        if case .bookFinished(let closed, let finished) = result {
            #expect(closed.persistentModelID == chapter.persistentModelID)
            #expect(finished.persistentModelID == story.persistentModelID)
        } else {
            Issue.record("Expected .bookFinished, got \(result)")
        }
    }

    @Test("finishBook moves story from active to completedStories")
    func finishMovesStory() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let dog = makeDog(in: context)
        let (story, chapter) = makeActiveStory(for: dog, in: context)
        try context.save()

        #expect(dog.story?.persistentModelID == story.persistentModelID)
        #expect((dog.completedStories ?? []).isEmpty)

        _ = StoryService.finishBook(
            story: story,
            closingChapter: chapter,
            bookTitle: "T",
            bookClosingLine: "C",
            dog: dog,
            modelContext: context
        )

        #expect(dog.story == nil)
        #expect(dog.completedStories?.count == 1)
        #expect(dog.completedStories?.first?.persistentModelID == story.persistentModelID)
    }

    @Test("finishBook synthesises a fallback title when none provided")
    func finishSynthesisesFallbackTitle() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let dog = makeDog(in: context)
        let (story, chapter) = makeActiveStory(for: dog, in: context)
        try context.save()

        _ = StoryService.finishBook(
            story: story,
            closingChapter: chapter,
            bookTitle: "",   // empty — caller couldn't reach the LLM
            bookClosingLine: "",
            dog: dog,
            modelContext: context
        )

        // Fallback shape: "<dogName>'s <Genre>"
        #expect(story.title.contains("Bonnie"))
        #expect(story.title.contains(StoryGenre.cosyMystery.displayName))
    }

    @Test("finishBook is idempotent — calling twice doesn't duplicate")
    func finishIsIdempotent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let dog = makeDog(in: context)
        let (story, chapter) = makeActiveStory(for: dog, in: context)
        try context.save()

        _ = StoryService.finishBook(
            story: story,
            closingChapter: chapter,
            bookTitle: "First",
            bookClosingLine: "C",
            dog: dog,
            modelContext: context
        )
        _ = StoryService.finishBook(
            story: story,
            closingChapter: chapter,
            bookTitle: "Second",
            bookClosingLine: "C",
            dog: dog,
            modelContext: context
        )

        #expect(dog.completedStories?.count == 1)
    }

    @Test("StoryGenre.chaptersPerBook is 5")
    func chaptersPerBookIsFive() {
        for genre in StoryGenre.allCases {
            #expect(genre.chaptersPerBook == 5)
        }
    }

    @Test("Dog.completedStoriesSorted returns newest first")
    func completedStoriesSorted() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let dog = makeDog(in: context)
        let older = Story(genre: .cosyMystery)
        older.finishedAt = Date(timeIntervalSinceNow: -86400 * 30)
        older.title = "Older"
        let newer = Story(genre: .cosyMystery)
        newer.finishedAt = Date(timeIntervalSinceNow: -86400)
        newer.title = "Newer"
        context.insert(older)
        context.insert(newer)
        dog.completedStories = [older, newer]
        try context.save()

        let sorted = dog.completedStoriesSorted
        #expect(sorted.count == 2)
        #expect(sorted.first?.title == "Newer")
        #expect(sorted.last?.title == "Older")
    }
}
