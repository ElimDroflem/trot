import Foundation

/// The journey mechanic: each minute walked moves the dog along an active route.
/// Landmarks unlock as cumulative `routeProgressKm` crosses their `kmFromStart`.
/// When a route is fully traversed, the dog auto-advances to the next route in the
/// sequence (with any residual km carried over).
///
/// Pure-function namespace, same shape as `StreakService`/`MilestoneService`.
/// Mutates the passed-in `Dog` in `applyWalk` (caller saves the model context).
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

    // MARK: - Pace

    /// Walking pace in km/h, modulated by the dog's owner-rated activity level.
    static func paceKmH(for activityLevel: ActivityLevel) -> Double {
        switch activityLevel {
        case .low: return 4.0
        case .moderate: return 5.0
        case .high: return 5.5
        }
    }

    /// Distance covered in `minutes` at the given pace.
    static func km(forMinutes minutes: Int, pace: Double) -> Double {
        guard minutes > 0, pace > 0 else { return 0 }
        return (pace / 60.0) * Double(minutes)
    }

    // MARK: - Walk application (mutates dog)

    /// Apply a walk of `minutes` minutes to the dog. Mutates `dog.routeProgressKm`
    /// (and possibly `dog.activeRouteID` + `dog.completedRouteIDs` if the walk
    /// completes the active route). Returns the structured outcome for the
    /// celebration flow to render.
    @discardableResult
    static func applyWalk(minutes: Int, to dog: Dog, in routes: [Route] = allRoutes) -> WalkApplication {
        guard minutes > 0 else {
            return WalkApplication(kmAdded: 0, landmarksCrossed: [], routeCompleted: nil, nextRoute: nil)
        }

        let pace = paceKmH(for: dog.activityLevel)
        let totalAdded = km(forMinutes: minutes, pace: pace)

        var allCrossings: [Landmark] = []
        var firstCompletedRoute: Route?
        var firstNextRoute: Route?
        var remaining = totalAdded
        // Safety bound: at most 4 route completions in a single walk. A 24-hour
        // walk at high pace covers ~130km; the longest single route is 160km;
        // realistically this loop runs once even for absurd walks.
        var safety = 4

        while remaining > 0, safety > 0 {
            safety -= 1
            guard let route = currentRoute(for: dog, in: routes) else { break }
            let oldKm = dog.routeProgressKm
            let proposedKm = oldKm + remaining

            if proposedKm < route.totalKm {
                // Stays within current route.
                let crossings = landmarksCrossed(from: oldKm, to: proposedKm, in: route)
                allCrossings.append(contentsOf: crossings)
                dog.routeProgressKm = proposedKm
                remaining = 0
            } else {
                // Walk completes (or overflows) the current route.
                let consumedKm = route.totalKm - oldKm
                let crossings = landmarksCrossed(from: oldKm, to: route.totalKm, in: route)
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
                dog.routeProgressKm = 0
                remaining -= consumedKm
            }
        }

        return WalkApplication(
            kmAdded: totalAdded,
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

    /// Landmarks of `route` whose `kmFromStart` falls in `(startKm, endKm]`.
    /// Strictly-greater on the start so a landmark at exactly `startKm` doesn't
    /// re-fire (the user already crossed it on a previous walk).
    static func landmarksCrossed(
        from startKm: Double,
        to endKm: Double,
        in route: Route
    ) -> [Landmark] {
        guard endKm > startKm else { return [] }
        return route.landmarks
            .filter { $0.kmFromStart > startKm && $0.kmFromStart <= endKm }
            .sorted { $0.kmFromStart < $1.kmFromStart }
    }

    /// First landmark on the dog's current route that they haven't reached yet.
    /// Used by JourneyView ("240m to ???") and ExpeditionView (live countdown).
    static func nextLandmark(for dog: Dog, in routes: [Route] = allRoutes) -> NextLandmark? {
        guard let route = currentRoute(for: dog, in: routes) else { return nil }
        return nextLandmark(in: route, progressKm: dog.routeProgressKm)
    }

    /// Non-mutating variant. Takes a route + progress in km directly so callers
    /// (esp. ExpeditionView, which adds in-flight estimated km) can compute
    /// against a hypothetical position without touching the Dog model. Critical
    /// for any view that reads this in a computed property — `Dog` is a @Model
    /// reference type, mutating it from a render path causes infinite invalidate
    /// loops that freeze the UI.
    static func nextLandmark(in route: Route, progressKm: Double) -> NextLandmark? {
        guard let next = route.landmarks
            .filter({ $0.kmFromStart > progressKm })
            .min(by: { $0.kmFromStart < $1.kmFromStart })
        else { return nil }

        let meters = max(0, Int(((next.kmFromStart - progressKm) * 1000).rounded()))
        let isFinal = next.id == route.finalLandmark?.id
        return NextLandmark(landmark: next, metersAway: meters, isFinalLandmarkOfRoute: isFinal)
    }
}

// MARK: - Returned models

struct WalkApplication: Sendable {
    let kmAdded: Double
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
    let metersAway: Int
    let isFinalLandmarkOfRoute: Bool
}
