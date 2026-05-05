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
}
