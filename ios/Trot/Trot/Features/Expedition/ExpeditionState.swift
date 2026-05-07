import Foundation

/// State holder for an in-progress expedition (live walk).
///
/// Wall-clock based: `elapsedSeconds` is computed from `startedAt` so that
/// backgrounding the app doesn't lose time. A `Timer` ticks the value at 1Hz
/// while the sheet is open just to drive UI updates.
@Observable
final class ExpeditionState {
    let startedAt: Date
    private(set) var elapsedSeconds: Int = 0
    /// IDs of landmarks that have already had their mid-walk toast shown,
    /// so a single landmark doesn't re-fire if the user lingers near it.
    private(set) var firedLandmarkIDs: Set<String> = []

    init(startedAt: Date = .now) {
        self.startedAt = startedAt
    }

    func tick(now: Date = .now) {
        elapsedSeconds = max(0, Int(now.timeIntervalSince(startedAt)))
    }

    var elapsedMinutes: Int {
        Int(round(Double(elapsedSeconds) / 60.0))
    }

    func markLandmarkFired(_ id: String) {
        firedLandmarkIDs.insert(id)
    }
}
