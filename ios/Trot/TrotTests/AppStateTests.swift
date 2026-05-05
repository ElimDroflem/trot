import Testing
import Foundation
import SwiftData
@testable import Trot

@Suite("AppState selection")
@MainActor
struct AppStateTests {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: TrotSchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeDog(_ name: String, in context: ModelContext) -> Dog {
        let dog = Dog(
            name: name,
            breedPrimary: "Mixed",
            dateOfBirth: Date(timeIntervalSince1970: 0),
            weightKg: 10,
            sex: .female,
            isNeutered: true
        )
        context.insert(dog)
        return dog
    }

    @Test("nil selection falls back to first dog")
    func nilSelectionFallback() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let luna = makeDog("Luna", in: context)
        let bruno = makeDog("Bruno", in: context)
        try context.save()

        let state = AppState()
        let selected = state.selectedDog(from: [luna, bruno])
        #expect(selected?.name == "Luna")
    }

    @Test("explicit selection picks matching dog")
    func explicitSelection() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let luna = makeDog("Luna", in: context)
        let bruno = makeDog("Bruno", in: context)
        try context.save()

        let state = AppState()
        state.select(bruno)
        let selected = state.selectedDog(from: [luna, bruno])
        #expect(selected?.name == "Bruno")
    }

    @Test("stale selection (dog removed) falls back to first")
    func staleSelectionFallback() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let luna = makeDog("Luna", in: context)
        let bruno = makeDog("Bruno", in: context)
        try context.save()

        let state = AppState()
        state.select(bruno)

        // Bruno is no longer in the active list (e.g. archived)
        let selected = state.selectedDog(from: [luna])
        #expect(selected?.name == "Luna")
    }

    @Test("empty dogs returns nil")
    func emptyReturnsNil() {
        let state = AppState()
        #expect(state.selectedDog(from: []) == nil)
    }
}
