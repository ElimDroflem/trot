import Foundation

/// The journey mechanic: each minute walked moves the dog along an active route.
/// Landmarks unlock as cumulative `routeProgressMinutes` crosses their
/// `minutesFromStart`. When a route is fully traversed, the dog auto-advances
/// to the next route in the sequence (with any residual minutes carried over).
///
/// Pure-function namespace, same shape as `StreakService`/`MilestoneService`.
/// Mutates the passed-in `Dog` in `applyWalk` (caller saves the model context).
///
/// **Time, not distance.** The app collects walk duration only. We never measure
/// real km. Routes are sized in minutes (calibrated against ~5 km/h so the
/// real-world geography stays meaningful as flavor) and progression is
/// `+minutes`. See `JourneyService+Routes.swift` for the rationale in full.
enum JourneyService {
    /// Fixed unlock order. After the final route completes, loops back to the starter
    /// — extremely rare in v1 (~3+ months of walking to clear all four routes).
    static let routeSequence: [String] = [
        "trot-first-walk",
        "london-brighton",
        "hadrians-wall",
        "south-downs-way"
    ]

    /// All routes loaded once from the bundled `Routes.json`. Cached.
    /// On loader failure (missing file, malformed JSON), returns an empty list and
    /// `assertionFailure`s — bundled data missing is a build-time concern, not a
    /// user-time one.
    static let allRoutes: [Route] = {
        guard let url = Bundle.main.url(forResource: "Routes", withExtension: "json") else {
            assertionFailure("Routes.json missing from bundle")
            return []
        }
        do {
            let raw = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(RoutesFile.self, from: raw)
            return file.routes
        } catch {
            assertionFailure("Routes.json failed to decode: \(error)")
            return []
        }
    }()

    static func route(for id: String, in routes: [Route] = allRoutes) -> Route? {
        routes.first(where: { $0.id == id })
    }

    /// The route the dog is currently on. Falls back to the starter if the dog's
    /// `activeRouteID` doesn't match any provided route (defensive — should only
    /// happen if Routes.json shape changed under existing user data).
    static func currentRoute(for dog: Dog, in routes: [Route] = allRoutes) -> Route? {
        if let r = route(for: dog.activeRouteID, in: routes) { return r }
        return route(for: routeSequence.first ?? "", in: routes)
    }

    // MARK: - Walk application (mutates dog)

    /// Apply a walk of `minutes` minutes to the dog. Mutates
    /// `dog.routeProgressMinutes` (and possibly `dog.activeRouteID` +
    /// `dog.completedRouteIDs` if the walk completes the active route).
    /// Returns the structured outcome for the celebration flow to render.
    @discardableResult
    static func applyWalk(minutes: Int, to dog: Dog, in routes: [Route] = allRoutes) -> WalkApplication {
        guard minutes > 0 else {
            return WalkApplication(minutesAdded: 0, landmarksCrossed: [], routeCompleted: nil, nextRoute: nil)
        }

        var allCrossings: [Landmark] = []
        var firstCompletedRoute: Route?
        var firstNextRoute: Route?
        var remaining = minutes
        // Safety bound: at most 4 route completions in a single walk. Even a
        // 24-hour single walk wouldn't clear the 32-hour South Downs route, so
        // this loop runs once for any realistic walk.
        var safety = 4

        while remaining > 0, safety > 0 {
            safety -= 1
            guard let route = currentRoute(for: dog, in: routes) else { break }
            let oldMinutes = dog.routeProgressMinutes
            let proposedMinutes = oldMinutes + remaining

            if proposedMinutes < route.totalMinutes {
                // Stays within current route.
                let crossings = landmarksCrossed(from: oldMinutes, to: proposedMinutes, in: route)
                allCrossings.append(contentsOf: crossings)
                dog.routeProgressMinutes = proposedMinutes
                remaining = 0
            } else {
                // Walk completes (or overflows) the current route.
                let consumedMinutes = route.totalMinutes - oldMinutes
                let crossings = landmarksCrossed(from: oldMinutes, to: route.totalMinutes, in: route)
                allCrossings.append(contentsOf: crossings)

                if firstCompletedRoute == nil {
                    firstCompletedRoute = route
                }
                if !dog.completedRouteIDs.contains(route.id) {
                    dog.completedRouteIDs.append(route.id)
                }

                let nextID = nextRouteID(after: route.id)
                if firstNextRoute == nil {
                    firstNextRoute = self.route(for: nextID, in: routes)
                }
                dog.activeRouteID = nextID
                dog.routeProgressMinutes = 0
                remaining -= consumedMinutes
            }
        }

        return WalkApplication(
            minutesAdded: minutes,
            landmarksCrossed: allCrossings,
            routeCompleted: firstCompletedRoute,
            nextRoute: firstNextRoute
        )
    }

    /// Successor in the fixed `routeSequence`. Loops back to the start if `id` is
    /// the final route (or unknown).
    static func nextRouteID(after id: String) -> String {
        guard let idx = routeSequence.firstIndex(of: id) else {
            return routeSequence.first ?? id
        }
        let nextIdx = (idx + 1) % routeSequence.count
        return routeSequence[nextIdx]
    }

    // MARK: - Pure queries

    /// Landmarks of `route` whose `minutesFromStart` falls in `(startMinutes, endMinutes]`.
    /// Strictly-greater on the start so a landmark at exactly `startMinutes` doesn't
    /// re-fire (the user already crossed it on a previous walk).
    static func landmarksCrossed(
        from startMinutes: Int,
        to endMinutes: Int,
        in route: Route
    ) -> [Landmark] {
        guard endMinutes > startMinutes else { return [] }
        return route.landmarks
            .filter { $0.minutesFromStart > startMinutes && $0.minutesFromStart <= endMinutes }
            .sorted { $0.minutesFromStart < $1.minutesFromStart }
    }

    /// First landmark on the dog's current route that they haven't reached yet.
    /// Used by JourneyView ("12 min to ???") and ExpeditionView (live countdown).
    static func nextLandmark(for dog: Dog, in routes: [Route] = allRoutes) -> NextLandmark? {
        guard let route = currentRoute(for: dog, in: routes) else { return nil }
        return nextLandmark(in: route, progressMinutes: dog.routeProgressMinutes)
    }

    /// Non-mutating variant. Takes a route + progress in minutes directly so
    /// callers (esp. ExpeditionView, which adds in-flight elapsed minutes) can
    /// compute against a hypothetical position without touching the Dog model.
    /// Critical for any view that reads this in a computed property — `Dog` is
    /// a @Model reference type, mutating it from a render path causes infinite
    /// invalidate loops that freeze the UI.
    static func nextLandmark(in route: Route, progressMinutes: Int) -> NextLandmark? {
        guard let next = route.landmarks
            .filter({ $0.minutesFromStart > progressMinutes })
            .min(by: { $0.minutesFromStart < $1.minutesFromStart })
        else { return nil }

        let minutesAway = max(0, next.minutesFromStart - progressMinutes)
        let isFinal = next.id == route.finalLandmark?.id
        return NextLandmark(landmark: next, minutesAway: minutesAway, isFinalLandmarkOfRoute: isFinal)
    }
}

// MARK: - Returned models

struct WalkApplication: Sendable {
    /// Minutes credited to the route by this walk. Equal to the saved walk's
    /// `durationMinutes` unless the walk straddled a route boundary, in which
    /// case still the full walk duration — the active route advances mid-walk.
    let minutesAdded: Int
    /// Every landmark crossed by this single walk, in order. May span more than
    /// one route if the walk was long enough to complete a route mid-stride.
    let landmarksCrossed: [Landmark]
    /// The route that finished during this walk, if any. Nil for a normal walk
    /// that didn't reach the end of the active route.
    let routeCompleted: Route?
    /// The route the dog is now on, if a completion occurred. Nil otherwise.
    let nextRoute: Route?
}

struct NextLandmark: Sendable {
    let landmark: Landmark
    /// Minutes of walking remaining before this landmark unlocks. 0 means the
    /// dog is right at it.
    let minutesAway: Int
    let isFinalLandmarkOfRoute: Bool
}
