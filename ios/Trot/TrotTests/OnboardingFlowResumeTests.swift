import Testing
import Foundation
import SwiftData
@testable import Trot

@Suite("OnboardingFlowView resume logic")
@MainActor
struct OnboardingFlowResumeTests {

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

    @Test("no dog yet → land on profile step")
    func noDogLandsOnProfile() {
        #expect(OnboardingFlowView.resumeStep(for: nil) == .profile)
    }

    @Test("dog without story → land on genre step")
    func dogWithoutStoryLandsOnGenre() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let dog = makeDog(in: context)
        try context.save()

        #expect(dog.story == nil)
        #expect(OnboardingFlowView.resumeStep(for: dog) == .genre)
    }

    @Test("dog with story → land on permissions step")
    func dogWithStoryLandsOnPermissions() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let dog = makeDog(in: context)
        let story = Story(genre: .cosyMystery)
        story.sceneRaw = "village"
        dog.story = story
        context.insert(story)
        try context.save()

        #expect(dog.story != nil)
        #expect(OnboardingFlowView.resumeStep(for: dog) == .permissions)
    }
}
