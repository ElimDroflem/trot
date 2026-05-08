import Testing
import Foundation
@testable import Trot

@Suite("Dog model")
struct DogModelTests {
    /// Tripwire test for the deprecated journey fields removed in 2026-05-08's
    /// refactor. If anyone reintroduces them by accident this fails loudly.
    @Test("Dog has no deprecated journey fields")
    func dogHasNoDeprecatedJourneyFields() {
        let dog = Dog(
            name: "Test",
            breedPrimary: "Beagle",
            dateOfBirth: Date(timeIntervalSince1970: 0),
            weightKg: 10,
            sex: .female,
            isNeutered: true
        )
        let names = Set(Mirror(reflecting: dog).children.compactMap(\.label))
        #expect(!names.contains("activeRouteID"))
        #expect(!names.contains("routeProgressMinutes"))
        #expect(!names.contains("completedRouteIDs"))
    }
}
