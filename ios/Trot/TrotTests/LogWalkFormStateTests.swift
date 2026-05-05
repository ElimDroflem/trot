import Testing
import Foundation
@testable import Trot

@Suite("LogWalkFormState validation")
struct LogWalkFormStateTests {

    @Test("default state is valid (30 min, now)")
    func defaultIsValid() {
        let state = LogWalkFormState()
        #expect(state.isValid == true)
    }

    @Test("zero or negative duration is invalid")
    func nonPositiveDurationInvalid() {
        var state = LogWalkFormState()
        state.durationMinutes = 0
        #expect(state.isValid == false)

        state.durationMinutes = -5
        #expect(state.isValid == false)

        state.durationMinutes = 1
        #expect(state.isValid == true)
    }

    @Test("future startedAt is invalid")
    func futureDateInvalid() {
        var state = LogWalkFormState()
        state.startedAt = .now.addingTimeInterval(60 * 60)
        #expect(state.isValid == false)
    }

    @Test("makeWalk uses .manual source and trims notes")
    func makeWalkProducesManualWalk() {
        var state = LogWalkFormState()
        state.startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        state.durationMinutes = 45
        state.notes = "  good boy walked nicely  "

        let walk = state.makeWalk(for: [])
        #expect(walk.durationMinutes == 45)
        #expect(walk.source == .manual)
        #expect(walk.distanceMeters == nil)
        #expect(walk.notes == "good boy walked nicely")
        #expect(walk.startedAt == Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test("makeWalk credits all provided dogs")
    func makeWalkCreditsAllDogs() {
        let luna = Dog(
            name: "Luna",
            breedPrimary: "Beagle",
            dateOfBirth: Date(timeIntervalSince1970: 0),
            weightKg: 12,
            sex: .female,
            isNeutered: true
        )
        let bruno = Dog(
            name: "Bruno",
            breedPrimary: "Lab",
            dateOfBirth: Date(timeIntervalSince1970: 0),
            weightKg: 30,
            sex: .male,
            isNeutered: false
        )

        let state = LogWalkFormState()
        let walk = state.makeWalk(for: [luna, bruno])

        #expect(walk.dogs?.count == 2)
        #expect(walk.dogs?.contains(where: { $0.name == "Luna" }) == true)
        #expect(walk.dogs?.contains(where: { $0.name == "Bruno" }) == true)
    }

    @Test("from(walk) round-trips into apply(to:)")
    func roundTripFromApply() {
        let original = Walk(
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            durationMinutes: 42,
            distanceMeters: 2800,
            source: .passive,
            notes: "good walk",
            dogs: []
        )

        var state = LogWalkFormState.from(original)
        #expect(state.startedAt == original.startedAt)
        #expect(state.durationMinutes == 42)
        #expect(state.notes == "good walk")

        // Mutate state and apply back
        state.durationMinutes = 55
        state.notes = "  edited notes  "
        state.startedAt = Date(timeIntervalSince1970: 1_700_001_000)
        state.apply(to: original)

        #expect(original.durationMinutes == 55)
        #expect(original.notes == "edited notes")
        #expect(original.startedAt == Date(timeIntervalSince1970: 1_700_001_000))
        #expect(original.source == .passive, "apply doesn't change source")
        #expect(original.distanceMeters == 2800, "apply doesn't change distance")
    }
}
