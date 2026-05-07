import Testing
import Foundation
@testable import Trot

@Suite("JourneyService")
struct JourneyServiceTests {

    // MARK: - Synthetic test routes (decoupled from bundled Routes.json)

    /// Three short routes that match the bundled `routeSequence` ordering so the
    /// auto-advance + carry-over logic reads off the same successor IDs.
    /// Lengths are in MINUTES (the unit of progression). Synthetic numbers are
    /// kept small and divisible so the math reads straight from the assertions.
    private static let testRoutes: [Route] = [
        Route(
            id: "trot-first-walk",
            name: "Test Starter",
            subtitle: "Synthetic",
            theme: .townLane,
            totalMinutes: 24,
            landmarks: [
                Landmark(id: "a", name: "A", description: "", minutesFromStart: 6, symbolName: "drop.fill"),
                Landmark(id: "b", name: "B", description: "", minutesFromStart: 12, symbolName: "tree.fill"),
                Landmark(id: "c", name: "C", description: "", minutesFromStart: 18, symbolName: "leaf.fill"),
                Landmark(id: "z", name: "End", description: "", minutesFromStart: 24, symbolName: "flag.fill")
            ],
            pathPoints: []
        ),
        Route(
            id: "london-brighton",
            name: "Test Two",
            subtitle: "Synthetic",
            theme: .coastal,
            totalMinutes: 60,
            landmarks: [
                Landmark(id: "x", name: "X", description: "", minutesFromStart: 12, symbolName: "drop.fill"),
                Landmark(id: "y", name: "Y", description: "", minutesFromStart: 60, symbolName: "flag.fill")
            ],
            pathPoints: []
        ),
        Route(
            id: "hadrians-wall",
            name: "Test Three",
            subtitle: "Synthetic",
            theme: .roman,
            totalMinutes: 120,
            landmarks: [
                Landmark(id: "h1", name: "H1", description: "", minutesFromStart: 60, symbolName: "drop.fill"),
                Landmark(id: "h2", name: "H2", description: "", minutesFromStart: 120, symbolName: "flag.fill")
            ],
            pathPoints: []
        )
    ]

    private func makeDog(
        activityLevel: ActivityLevel = .moderate,
        activeRouteID: String = "trot-first-walk",
        progressMinutes: Int = 0,
        completedRouteIDs: [String] = []
    ) -> Dog {
        let dog = Dog(
            name: "Test",
            breedPrimary: "Mixed",
            dateOfBirth: Date(timeIntervalSince1970: 0),
            weightKg: 10,
            sex: .female,
            isNeutered: true,
            activityLevel: activityLevel
        )
        dog.activeRouteID = activeRouteID
        dog.routeProgressMinutes = progressMinutes
        dog.completedRouteIDs = completedRouteIDs
        return dog
    }

    // MARK: - landmarksCrossed (pure function)

    @Test("landmarksCrossed: strict-greater on start avoids re-firing")
    func crossingsStrictGreater() {
        let route = Self.testRoutes[0]
        // Walk from minute 6 (already at landmark A) to minute 12 (lands on B)
        let crossed = JourneyService.landmarksCrossed(from: 6, to: 12, in: route)
        #expect(crossed.map(\.id) == ["b"], "A is at the start, not a new crossing; B is reached")
    }

    @Test("landmarksCrossed: multiple crossings ordered by minutes")
    func crossingsMultiple() {
        let route = Self.testRoutes[0]
        let crossed = JourneyService.landmarksCrossed(from: 0, to: 19, in: route)
        #expect(crossed.map(\.id) == ["a", "b", "c"])
    }

    @Test("landmarksCrossed: empty when end ≤ start")
    func crossingsEmpty() {
        let route = Self.testRoutes[0]
        #expect(JourneyService.landmarksCrossed(from: 6, to: 6, in: route).isEmpty)
        #expect(JourneyService.landmarksCrossed(from: 12, to: 6, in: route).isEmpty)
    }

    // MARK: - applyWalk (mutates Dog)

    @Test("applyWalk: simple progression within route")
    func applyWalkSimple() {
        let dog = makeDog()
        let result = JourneyService.applyWalk(minutes: 12, to: dog, in: Self.testRoutes)
        #expect(result.minutesAdded == 12)
        #expect(dog.routeProgressMinutes == 12)
        #expect(dog.activeRouteID == "trot-first-walk")
        #expect(dog.completedRouteIDs.isEmpty)
        #expect(result.routeCompleted == nil)
        #expect(result.landmarksCrossed.map(\.id) == ["a", "b"])
    }

    @Test("applyWalk: zero/negative minutes is a no-op")
    func applyWalkZero() {
        let dog = makeDog(progressMinutes: 6)
        let result = JourneyService.applyWalk(minutes: 0, to: dog, in: Self.testRoutes)
        #expect(result.minutesAdded == 0)
        #expect(dog.routeProgressMinutes == 6)
        #expect(result.landmarksCrossed.isEmpty)
    }

    @Test("applyWalk: completes route, advances to next, carries overflow")
    func applyWalkCompletion() {
        // Starter is 24 min. Walk 30 min. Completes starter, carries 6 min onto
        // london-brighton.
        let dog = makeDog()
        let result = JourneyService.applyWalk(minutes: 30, to: dog, in: Self.testRoutes)

        #expect(dog.activeRouteID == "london-brighton", "auto-advanced after starter")
        #expect(dog.routeProgressMinutes == 6, "overflow carried over")
        #expect(dog.completedRouteIDs == ["trot-first-walk"])
        #expect(result.routeCompleted?.id == "trot-first-walk")
        #expect(result.nextRoute?.id == "london-brighton")
        // Crossings should include all four starter landmarks (final at 24 IS reached)
        #expect(result.landmarksCrossed.map(\.id).contains("a"))
        #expect(result.landmarksCrossed.map(\.id).contains("z"))
    }

    @Test("applyWalk: massive walk completes multiple routes")
    func applyWalkMultipleCompletion() {
        // 90 minutes. Completes starter (24) + london-brighton (60) and lands
        // 6 min into hadrians-wall.
        let dog = makeDog()
        let result = JourneyService.applyWalk(minutes: 90, to: dog, in: Self.testRoutes)

        #expect(dog.activeRouteID == "hadrians-wall")
        #expect(dog.routeProgressMinutes == 6)
        #expect(dog.completedRouteIDs == ["trot-first-walk", "london-brighton"])
        // Only the FIRST completed route surfaces in the result (walk-complete UI
        // shows one celebration, not a cascade)
        #expect(result.routeCompleted?.id == "trot-first-walk")
        #expect(result.nextRoute?.id == "london-brighton")
    }

    @Test("applyWalk: doesn't double-add a completed route ID")
    func noDoubleCompletion() {
        // Manually pre-mark starter as completed; finishing it again shouldn't
        // duplicate the ID
        let dog = makeDog(completedRouteIDs: ["trot-first-walk"])
        JourneyService.applyWalk(minutes: 30, to: dog, in: Self.testRoutes)
        let count = dog.completedRouteIDs.filter { $0 == "trot-first-walk" }.count
        #expect(count == 1, "completedRouteIDs is dedupe-on-insert")
    }

    // MARK: - nextRouteID

    @Test("nextRouteID: cycles through the sequence")
    func nextRouteIDCycle() {
        #expect(JourneyService.nextRouteID(after: "trot-first-walk") == "london-brighton")
        #expect(JourneyService.nextRouteID(after: "london-brighton") == "hadrians-wall")
        #expect(JourneyService.nextRouteID(after: "hadrians-wall") == "south-downs-way")
        #expect(JourneyService.nextRouteID(after: "south-downs-way") == "trot-first-walk",
                "loops back to starter after the final route")
    }

    @Test("nextRouteID: unknown ID falls back to first")
    func nextRouteIDUnknown() {
        #expect(JourneyService.nextRouteID(after: "nonsense") == "trot-first-walk")
    }

    // MARK: - nextLandmark

    @Test("nextLandmark: returns closest unreached landmark with minutesAway")
    func nextLandmarkBasic() {
        let dog = makeDog(progressMinutes: 4)
        guard let next = JourneyService.nextLandmark(for: dog, in: Self.testRoutes) else {
            Issue.record("Expected a next landmark"); return
        }
        #expect(next.landmark.id == "a")
        #expect(next.minutesAway == 2)  // 6 - 4
        #expect(!next.isFinalLandmarkOfRoute)
    }

    @Test("nextLandmark: identifies the route's final landmark")
    func nextLandmarkFinal() {
        let dog = makeDog(progressMinutes: 19)  // Past A, B, C; only Z (at 24) remains
        guard let next = JourneyService.nextLandmark(for: dog, in: Self.testRoutes) else {
            Issue.record("Expected a next landmark"); return
        }
        #expect(next.landmark.id == "z")
        #expect(next.isFinalLandmarkOfRoute)
        #expect(next.minutesAway == 5)
    }

    @Test("nextLandmark: nil after the last landmark")
    func nextLandmarkPastEnd() {
        // Edge: dog's progress equals totalMinutes exactly. No landmarks strictly past.
        let dog = makeDog(progressMinutes: 24)
        let next = JourneyService.nextLandmark(for: dog, in: Self.testRoutes)
        #expect(next == nil)
    }

    @Test("nextLandmark(in:progressMinutes:) — non-mutating overload")
    func nextLandmarkNonMutating() {
        // Sanity: the in: overload reads the same data without needing a Dog.
        let route = Self.testRoutes[0]
        let next = JourneyService.nextLandmark(in: route, progressMinutes: 4)
        #expect(next?.landmark.id == "a")
        #expect(next?.minutesAway == 2)
    }

    @Test("currentRoute: falls back to starter on unknown active ID")
    func currentRouteFallback() {
        let dog = makeDog(activeRouteID: "nonsense-id")
        let route = JourneyService.currentRoute(for: dog, in: Self.testRoutes)
        #expect(route?.id == "trot-first-walk")
    }
}
