import Foundation
import SwiftData

/// App-wide state injected via SwiftUI's environment.
/// Tracks the user's currently-selected dog across tabs and a queue of
/// pending first-week-loop celebrations to surface to the user.
/// Falls back to the most-recently-active dog when nothing is explicitly selected.
/// The five primary tabs in HomeView's TabView. Bound to via `AppState.selectedTab`
/// so DEBUG deep-link navigation (`trot://debug/tab/<name>`) can drive selection.
enum TrotTab: String, Hashable, Sendable {
    case today
    case activity
    case journey
    case insights
    case dog
}

@Observable
final class AppState {
    var selectedDogID: PersistentIdentifier?

    /// Currently-selected tab in the bottom tab bar. Defaults to .today;
    /// updated by user taps via `TabView(selection:)` and (in DEBUG) by
    /// `trot://debug/tab/<name>` deep links.
    var selectedTab: TrotTab = .today

    /// DEBUG-only escape hatch for the onboarding gate. Set via deep link
    /// (`trot://debug/tab/...` flips this true) so simulator-driven testing
    /// can navigate past the Sign-in screen without UI automation. Treated
    /// as `false` by default; never read in Release.
    var debugGateBypassed: Bool = false

    /// FIFO queue of milestone celebrations waiting to be shown.
    /// Producer (LogWalkSheet save, RootView .task) pushes new beats from
    /// `MilestoneService.newMilestones(for:)`. Consumer (a celebration overlay
    /// on Home) reads `pendingCelebration` and dismisses by calling `consumeCelebration()`.
    var pendingCelebrations: [PendingCelebration] = []

    var pendingCelebration: PendingCelebration? { pendingCelebrations.first }

    /// Set to a dog's PersistentIdentifier when the weekly recap should auto-present.
    /// RootView observes and drives the sheet. Cleared on dismiss.
    var pendingRecapDogID: PersistentIdentifier?

    /// FIFO queue of walk-complete celebrations. Every walk save (manual log
    /// or expedition mode) enqueues one; `WalkCompleteOverlay` reads the head
    /// and dismisses via `consumeWalkComplete()`. Surfaced ABOVE milestones in
    /// `RootView` so the immediate "you just walked" moment lands first.
    var pendingWalkCompletes: [PendingWalkComplete] = []

    var pendingWalkComplete: PendingWalkComplete? { pendingWalkCompletes.first }

    init(selectedDogID: PersistentIdentifier? = nil) {
        self.selectedDogID = selectedDogID
        #if DEBUG
        applyLaunchArgumentOverrides()
        #endif
    }

    #if DEBUG
    /// Apply DEBUG-only overrides written via UserDefaults launch arguments.
    /// `xcrun simctl launch --args` injects these for the launch only — they
    /// don't persist across runs. Used by simulator-driven testing to skip
    /// the gate and land on a target tab without UI automation.
    ///
    ///     xcrun simctl launch --console booted dog.trot.Trot \
    ///         -DebugGateBypassed YES -DebugTab journey
    private func applyLaunchArgumentOverrides() {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "DebugGateBypassed") {
            debugGateBypassed = true
        }
        if let raw = defaults.string(forKey: "DebugTab"),
           let tab = TrotTab(rawValue: raw.lowercased()) {
            selectedTab = tab
        }
    }
    #endif

    /// Returns the dog that should be displayed given the current selection and the
    /// available active dogs. If `selectedDogID` is unset or doesn't match any active
    /// dog (e.g. that dog was archived), falls back to `dogs.first`.
    func selectedDog(from dogs: [Dog]) -> Dog? {
        if let id = selectedDogID,
           let match = dogs.first(where: { $0.persistentModelID == id }) {
            return match
        }
        return dogs.first
    }

    /// Mark a dog as the active selection.
    func select(_ dog: Dog) {
        selectedDogID = dog.persistentModelID
    }

    /// Append celebrations for a given dog. Caller is responsible for having
    /// already called `MilestoneService.markFired(_:on:)` and saved the model
    /// context — this queue is purely for surfacing the moment to the user.
    func enqueueCelebrations(_ codes: [MilestoneCode], for dog: Dog) {
        guard !codes.isEmpty else { return }
        let dogName = dog.name.isEmpty ? "Your dog" : dog.name
        let entries = codes.map { PendingCelebration(code: $0, dogName: dogName) }
        pendingCelebrations.append(contentsOf: entries)
    }

    /// Pops the head of the celebration queue. Called by the overlay on dismiss.
    func consumeCelebration() {
        guard !pendingCelebrations.isEmpty else { return }
        pendingCelebrations.removeFirst()
    }

    /// Append a walk-complete event for the given walk save. Built from the
    /// `WalkApplication` returned by `JourneyService.applyWalk(...)` so the
    /// overlay can render route advance + landmark stamps.
    func enqueueWalkComplete(
        dog: Dog,
        minutes: Int,
        isFirstWalk: Bool,
        application: WalkApplication,
        oldProgressKm: Double,
        newProgressKm: Double,
        routeName: String,
        routeTotalKm: Double
    ) {
        let nextLandmark = JourneyService.nextLandmark(for: dog)?.landmark.name
        let event = PendingWalkComplete(
            dogID: dog.persistentModelID,
            dogName: dog.name.isEmpty ? "Your dog" : dog.name,
            minutes: minutes,
            isFirstWalk: isFirstWalk,
            kmAdded: application.kmAdded,
            oldProgressKm: oldProgressKm,
            newProgressKm: newProgressKm,
            routeName: routeName,
            routeTotalKm: routeTotalKm,
            landmarksCrossed: application.landmarksCrossed,
            nextLandmarkName: nextLandmark,
            routeCompleted: application.routeCompleted?.name
        )
        pendingWalkCompletes.append(event)
    }

    /// Pops the head of the walk-complete queue.
    func consumeWalkComplete() {
        guard !pendingWalkCompletes.isEmpty else { return }
        pendingWalkCompletes.removeFirst()
    }
}

/// A queued celebration waiting to be surfaced. Captures `dogName` at enqueue
/// time so the title/body don't change if the user switches dogs before the
/// overlay is shown.
struct PendingCelebration: Identifiable, Equatable, Sendable {
    let id = UUID()
    let code: MilestoneCode
    let dogName: String

    var title: String { code.title(dogName: dogName) }
    var body: String { code.body(dogName: dogName) }
}

/// A walk has just been saved. Carries the data the `WalkCompleteOverlay`
/// needs to render: dopamine headline + route bar advance + (optional)
/// landmark stamps + (rare) route-completion line.
struct PendingWalkComplete: Identifiable, Sendable {
    let id = UUID()
    /// The dog that was walked. Carried through so `WalkCompleteOverlay` can
    /// fetch a dog-voice line from `LLMService` without re-resolving from a
    /// query.
    let dogID: PersistentIdentifier
    let dogName: String
    let minutes: Int
    /// True when this was the dog's first-ever logged walk. Used to push the
    /// LLM toward a more cinematic post-walk line. The visual milestone
    /// celebration for "first walk" rides on top via `MilestoneService`.
    let isFirstWalk: Bool
    let kmAdded: Double
    let oldProgressKm: Double
    let newProgressKm: Double
    let routeName: String
    let routeTotalKm: Double
    let landmarksCrossed: [Landmark]
    /// Name of the very next landmark the dog hasn't reached yet, if any.
    /// Lets the LLM hint at what's coming ("Tea Hut next time?").
    let nextLandmarkName: String?
    /// Non-nil if this walk closed out a route. The overlay swaps in a special
    /// "route finished" treatment in that case.
    let routeCompleted: String?

    var headline: String {
        "\(minutes) \(minutes == 1 ? "minute" : "minutes") with \(dogName)!"
    }

    /// 0...1 progress on the active route AT THE MOMENT the walk landed.
    /// Used by the overlay to animate the route bar from old to new.
    var oldFraction: Double {
        routeTotalKm > 0 ? min(1, max(0, oldProgressKm / routeTotalKm)) : 0
    }

    var newFraction: Double {
        routeTotalKm > 0 ? min(1, max(0, newProgressKm / routeTotalKm)) : 0
    }
}
