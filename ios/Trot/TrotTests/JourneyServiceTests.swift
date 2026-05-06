import Testing
import Foundation
@testable import Trot

@Suite("JourneyService")
struct JourneyServiceTests {

    // MARK: - Synthetic test routes (decoupled from bundled Routes.json)

    /// Three short routes that match the bundled `routeSequence` ordering so the
    /// auto-advance + carry-over logic reads off the same successor IDs.
    private static let testRoutes: [Route] = [
        Route(
            id: "trot-first-walk",
            name: "Test Starter",
            subtitle: "Synthetic",
            theme: .townLane,
            totalKm: 2.0,
            landmarks: [
                Landmark(id: "a", name: "A", description: "", kmFromStart: 0.5, symbolName: "drop.fill"),
                Landmark(id: "b", name: "B", description: "", kmFromStart: 1.0, symbolName: "tree.fill"),
                Landmark(id: "c", name: "C", description: "", kmFromStart: 1.5, symbolName: "leaf.fill"),
                Landmark(id: "z", name: "End", description: "", kmFromStart: 2.0, symbolName: "flag.fill")
            ],
            pathPoints: []
        ),
        Route(
            id: "london-brighton",
            name: "Test Two",
            subtitle: "Synthetic",
            theme: .coastal,
            totalKm: 5.0,
            landmarks: [
                Landmark(id: "x", name: "X", description: "", kmFromStart: 1.0, symbolName: "drop.fill"),
                Landmark(id: "y", name: "Y", description: "", kmFromStart: 5.0, symbolName: "flag.fill")
            ],
            pathPoints: []
        ),
        Route(
            id: "hadrians-wall",
            name: "Test Three",
            subtitle: "Synthetic",
            theme: .roman,
            totalKm: 10.0,
            landmarks: [
                Landmark(id: "h1", name: "H1", description: "", kmFromStart: 5.0, symbolName: "drop.fill"),
                Landmark(id: "h2", name: "H2", description: "", kmFromStart: 10.0, symbolName: "flag.fill")
            ],
            pathPoints: []
        )
    ]

    private func makeDog(
        activityLevel: ActivityLevel = .moderate,
        activeRouteID: String = "trot-first-walk",
        progressKm: Double = 0,
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
        dog.routeProgressKm = progressKm
        dog.completedRouteIDs = completedRouteIDs
        return dog
    }

    // MARK: - Pace + km conversion

    @Test("paceKmH varies by activity level")
    func paceVariesByActivityLevel() {
        #expect(JourneyService.paceKmH(for: .low) == 4.0)
        #expect(JourneyService.paceKmH(for: .moderate) == 5.0)
        #expect(JourneyService.paceKmH(for: .high) == 5.5)
    }

    @Test("km(forMinutes:pace:) is minutes/60 × pace")
    func kmConversion() {
        #expect(JourneyService.km(forMinutes: 60, pace: 5.0) == 5.0)
        #expect(JourneyService.km(forMinutes: 30, pace: 5.0) == 2.5)
        #expect(JourneyService.km(forMinutes: 12, pace: 5.0) == 1.0)
    }

    @Test("km is zero for zero/negative minutes")
    func kmZeroBranch() {
        #expect(JourneyService.km(forMinutes: 0, pace: 5.0) == 0)
        #expect(JourneyService.km(forMinutes: -5, pace: 5.0) == 0)
    }

    // MARK: - landmarksCrossed (pure function)

    @Test("landmarksCrossed: strict-greater on start avoids re-firing")
    func crossingsStrictGreater() {
        let route = Self.testRoutes[0]
        // Walk from 0.5 (already at landmark A) to 1.0 (lands on B)
        let crossed = JourneyService.landmarksCrossed(from: 0.5, to: 1.0, in: route)
        #expect(crossed.map(\.id) == ["b"], "A is at the start, not a new crossing; B is reached")
    }

    @Test("landmarksCrossed: multiple crossings ordered by km")
    func crossingsMultiple() {
        let route = Self.testRoutes[0]
        let crossed = JourneyService.landmarksCrossed(from: 0.0, to: 1.6, in: route)
        #expect(crossed.map(\.id) == ["a", "b", "c"])
    }

    @Test("landmarksCrossed: empty when end ≤ start")
    func crossingsEmpty() {
        let route = Self.testRoutes[0]
        #expect(JourneyService.landmarksCrossed(from: 0.5, to: 0.5, in: route).isEmpty)
        #expect(JourneyService.landmarksCrossed(from: 1.0, to: 0.5, in: route).isEmpty)
    }

    // MARK: - applyWalk (mutates Dog)

    @Test("applyWalk: simple progression within route")
    func applyWalkSimple() {
        let dog = makeDog()
        // 12 minutes at moderate pace (5km/h) = 1.0 km
        let result = JourneyService.applyWalk(minutes: 12, to: dog, in: Self.testRoutes)
        #expect(result.kmAdded == 1.0)
        #expect(dog.routeProgressKm == 1.0)
        #expect(dog.activeRouteID == "trot-first-walk")
        #expect(dog.completedRouteIDs.isEmpty)
        #expect(result.routeCompleted == nil)
        #expect(result.landmarksCrossed.map(\.id) == ["a", "b"])
    }

    @Test("applyWalk: zero/negative minutes is a no-op")
    func applyWalkZero() {
        let dog = makeDog(progressKm: 0.5)
        let result = JourneyService.applyWalk(minutes: 0, to: dog, in: Self.testRoutes)
        #expect(result.kmAdded == 0)
        #expect(dog.routeProgressKm == 0.5)
        #expect(result.landmarksCrossed.isEmpty)
    }

    @Test("applyWalk: completes route, advances to next, carries overflow")
    func applyWalkCompletion() {
        // Starter is 2km. Walk 30 min @ 5km/h = 2.5 km. Should complete starter
        // (consuming 2km), carry 0.5 km onto london-brighton (which has totalKm=5).
        let dog = makeDog()
        let result = JourneyService.applyWalk(minutes: 30, to: dog, in: Self.testRoutes)

        #expect(dog.activeRouteID == "london-brighton", "auto-advanced after starter")
        #expect(dog.routeProgressKm == 0.5, "overflow carried over")
        #expect(dog.completedRouteIDs == ["trot-first-walk"])
        #expect(result.routeCompleted?.id == "trot-first-walk")
        #expect(result.nextRoute?.id == "london-brighton")
        // Crossings should include all four starter landmarks (final at 2.0 IS reached)
        #expect(result.landmarksCrossed.map(\.id).contains("a"))
        #expect(result.landmarksCrossed.map(\.id).contains("z"))
    }

    @Test("applyWalk: massive walk completes multiple routes")
    func applyWalkMultipleCompletion() {
        // 90 min @ 5 km/h = 7.5 km. Completes starter (2km) + london-brighton (5km)
        // and lands 0.5km into hadrians-wall.
        let dog = makeDog()
        let result = JourneyService.applyWalk(minutes: 90, to: dog, in: Self.testRoutes)

        #expect(dog.activeRouteID == "hadrians-wall")
        #expect(abs(dog.routeProgressKm - 0.5) < 0.0001)
        #expect(dog.completedRouteIDs == ["trot-first-walk", "london-brighton"])
        // Only the FIRST completed route surfaces in the result (walk-complete UI
        // shows one celebration, not a cascade)
        #expect(result.routeCompleted?.id == "trot-first-walk")
        #expect(result.nextRoute?.id == "london-brighton")
    }

    @Test("applyWalk: respects activity-level pace")
    func applyWalkPace() {
        // 60 min @ low pace (4 km/h) = 4 km — completes starter (2km) + 2km into next
        let dog = makeDog(activityLevel: .low)
        JourneyService.applyWalk(minutes: 60, to: dog, in: Self.testRoutes)
        #expect(dog.activeRouteID == "london-brighton")
        #expect(abs(dog.routeProgressKm - 2.0) < 0.0001)
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

    @Test("nextLandmark: returns closest unreached landmark with metersAway")
    func nextLandmarkBasic() {
        let dog = makeDog(progressKm: 0.3)
        guard let next = JourneyService.nextLandmark(for: dog, in: Self.testRoutes) else {
            Issue.record("Expected a next landmark"); return
        }
        #expect(next.landmark.id == "a")
        // 0.5 - 0.3 = 0.2 km = 200m
        #expect(next.metersAway == 200)
        #expect(!next.isFinalLandmarkOfRoute)
    }

    @Test("nextLandmark: identifies the route's final landmark")
    func nextLandmarkFinal() {
        let dog = makeDog(progressKm: 1.6)  // Past A, B, C; only Z (at 2.0) remains
        guard let next = JourneyService.nextLandmark(for: dog, in: Self.testRoutes) else {
            Issue.record("Expected a next landmark"); return
        }
        #expect(next.landmark.id == "z")
        #expect(next.isFinalLandmarkOfRoute)
        #expect(next.metersAway == 400)
    }

    @Test("nextLandmark: nil after the last landmark")
    func nextLandmarkPastEnd() {
        // Edge: dog's progress equals totalKm exactly. No landmarks strictly past it.
        let dog = makeDog(progressKm: 2.0)
        let next = JourneyService.nextLandmark(for: dog, in: Self.testRoutes)
        #expect(next == nil)
    }

    @Test("currentRoute: falls back to starter on unknown active ID")
    func currentRouteFallback() {
        let dog = makeDog(activeRouteID: "nonsense-id")
        let route = JourneyService.currentRoute(for: dog, in: Self.testRoutes)
        #expect(route?.id == "trot-first-walk")
    }
}
