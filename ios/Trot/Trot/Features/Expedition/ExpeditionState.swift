import Foundation

/// State holder for an in-progress expedition (live walk).
///
/// Two phases:
///   - **Ready** (default after init): the sheet is open but the user
///     hasn't tapped Start yet. `startedAt` is nil; the timer doesn't
///     tick. Backgrounding the app while in this state doesn't accrue
///     phantom walk time.
///   - **Running** (after `start()`): `startedAt` captures the wall-clock
///     moment of tap. `elapsedSeconds` is computed from that anchor so
///     backgrounding the app *while running* doesn't lose time.
///
/// The 1Hz tick on `ExpeditionView` calls `tick()` which is a no-op
/// while ready.
@Observable
final class ExpeditionState {
    private(set) var startedAt: Date?
    private(set) var elapsedSeconds: Int = 0
    /// IDs of landmarks that have already had their mid-walk toast shown,
    /// so a single landmark doesn't re-fire if the user lingers near it.
    private(set) var firedLandmarkIDs: Set<String> = []

    var hasStarted: Bool { startedAt != nil }

    /// Begin counting time. Idempotent — calling twice does nothing
    /// extra; `startedAt` only captures the first tap.
    func start(now: Date = .now) {
        guard startedAt == nil else { return }
        startedAt = now
        elapsedSeconds = 0
    }

    func tick(now: Date = .now) {
        guard let startedAt else { return }
        elapsedSeconds = max(0, Int(now.timeIntervalSince(startedAt)))
    }

    var elapsedMinutes: Int {
        Int(round(Double(elapsedSeconds) / 60.0))
    }

    func markLandmarkFired(_ id: String) {
        firedLandmarkIDs.insert(id)
    }
}
