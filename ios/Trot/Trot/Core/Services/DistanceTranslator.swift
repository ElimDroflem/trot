import Foundation

/// Translates cumulative walking distance into a UK-flavoured real-world
/// reference. Spec: *"You and Bonnie have walked 18 km together. That's
/// Brighton to Hove."* The reference graduates with distance — at 5 km it's
/// "around your local park"; at 1,407 km it's "Land's End to John o'Groats."
///
/// Loaded once at app startup from `UKLandmarks.json`. Pure-function, no
/// network. Returns the *largest* milestone the user has reached (not the
/// nearest unreached) so the brag is always something they've earned.
enum DistanceTranslator {
    struct Milestone: Decodable {
        let km: Double
        let label: String
    }

    private static let milestones: [Milestone] = {
        guard let url = Bundle.main.url(forResource: "UKLandmarks", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        struct Wrapper: Decodable { let milestones: [Milestone] }
        let decoded = try? JSONDecoder().decode(Wrapper.self, from: data)
        return (decoded?.milestones ?? []).sorted { $0.km < $1.km }
    }()

    /// Returns the highest-km milestone the user has met or exceeded, or nil
    /// for cumulative distances below the smallest milestone (5 km). Caller
    /// should hide the line in that case rather than showing "you've walked
    /// 0.4 km, that's around your local park" — feels patronising.
    static func milestone(forKilometres km: Double) -> Milestone? {
        guard km > 0, !milestones.isEmpty else { return nil }
        return milestones.last { $0.km <= km }
    }

    /// Cumulative km across every walk for the dog. Uses
    /// `Walk.distanceMeters` when available (HealthKit pedometer-derived),
    /// estimates from duration otherwise (~70 m/min average walking pace).
    static func totalKilometres(for dog: Dog) -> Double {
        let walks = dog.walks ?? []
        let metres = walks.reduce(0.0) { acc, walk in
            if let d = walk.distanceMeters, d > 0 {
                return acc + d
            }
            // Fallback estimate keeps the lifetime line meaningful for any
            // walks logged before HealthKit started reporting distance, or
            // any manual logs without distance info.
            return acc + Double(walk.durationMinutes) * 70.0
        }
        return metres / 1000.0
    }
}
