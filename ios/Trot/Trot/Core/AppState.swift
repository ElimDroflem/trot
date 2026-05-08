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
    /// The book — per-dog AI-generated narrative that grows by one page
    /// per walk. Was named `.journey` in the v1 build that shipped a
    /// route-based Journey tab; replaced May 2026 by the Story rebuild.
    case story
    /// Phantom tab. Selecting it opens the walk-action menu; the selection
    /// auto-reverts to the previous tab. Sits in the centre slot of the
    /// bottom bar so the app's primary verb has a permanent home there.
    case walk
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

    /// Atmospheric context written by `WeatherMoodLayer` once it has a
    /// snapshot. Consumed by:
    ///   - card-border / shadow modifier (different border colour at night)
    ///   - tab headers that sit on top of the atmosphere (text colour swap
    ///     so deep-green `brandSecondary` doesn't disappear on a navy sky)
    ///
    /// Default is "day" so views render correctly on first paint before the
    /// snapshot lands.
    var atmosphereIsNight: Bool = false
    var atmosphereCategory: WeatherCategory? = nil

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
        // -DebugCelebrationMinutes N → enqueue a synthetic walk-complete event
        // so the WalkCompleteOverlay renders on first paint. Used by simulator
        // testing to QA the overlay without firing a real walk save (which
        // requires UI driving the LogWalkSheet or ExpeditionView). The dog ID
        // is filled in lazily by RootView once active dogs are queried.
        let celebrationMinutes = defaults.integer(forKey: "DebugCelebrationMinutes")
        if celebrationMinutes > 0 {
            pendingDebugCelebrationMinutes = celebrationMinutes
            pendingDebugCelebrationWithRoute = defaults.bool(forKey: "DebugCelebrationRoute")
        }
    }

    /// Captured launch-arg state for the synthetic celebration. RootView reads
    /// these once active dogs are available, builds the event, and clears.
    var pendingDebugCelebrationMinutes: Int?
    var pendingDebugCelebrationWithRoute: Bool = false
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
    ///
    /// `application`, `oldProgressMinutes`, `newProgressMinutes`, `routeName`,
    /// and `routeTotalMinutes` are nil when the dog has no active route — the
    /// overlay hides the route bar / landmark / completion sections cleanly
    /// in that case so the celebration still fires.
    func enqueueWalkComplete(
        dog: Dog,
        minutes: Int,
        isFirstWalk: Bool,
        application: WalkApplication?,
        oldProgressMinutes: Int = 0,
        newProgressMinutes: Int = 0,
        routeName: String? = nil,
        routeTotalMinutes: Int? = nil
    ) {
        let nextLandmark = JourneyService.nextLandmark(for: dog)?.landmark.name
        let event = PendingWalkComplete(
            dogID: dog.persistentModelID,
            dogName: dog.name.isEmpty ? "Your dog" : dog.name,
            minutes: minutes,
            isFirstWalk: isFirstWalk,
            minutesAdded: application?.minutesAdded ?? 0,
            oldProgressMinutes: oldProgressMinutes,
            newProgressMinutes: newProgressMinutes,
            routeName: routeName,
            routeTotalMinutes: routeTotalMinutes,
            landmarksCrossed: application?.landmarksCrossed ?? [],
            nextLandmarkName: nextLandmark,
            routeCompleted: application?.routeCompleted?.name
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
/// needs to render: dopamine headline + (optional) route bar advance +
/// (optional) landmark stamps + (rare) route-completion line.
///
/// Route fields are optional because not every dog has an active route — the
/// overlay degrades cleanly to "headline + photo + dog-voice line + confetti"
/// for routeless walks, which still reads as a celebration. (Earlier the
/// enqueue was gated on having a route, which silently swallowed celebrations
/// for any dog who'd finished their last route or never started one.)
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
    /// Minutes credited to the active route by this walk. Equal to `minutes`
    /// in normal cases; differs only on degenerate edge cases (zero-minute
    /// walks return 0 added). Zero when there's no active route.
    let minutesAdded: Int
    let oldProgressMinutes: Int
    let newProgressMinutes: Int
    /// Nil when the dog has no active route. Overlay hides the route bar.
    let routeName: String?
    /// Nil when the dog has no active route.
    let routeTotalMinutes: Int?
    let landmarksCrossed: [Landmark]
    /// Name of the very next landmark the dog hasn't reached yet, if any.
    /// Lets the LLM hint at what's coming ("Tea Hut next time?").
    let nextLandmarkName: String?
    /// Non-nil if this walk closed out a route. The overlay swaps in a special
    /// "route finished" treatment in that case.
    let routeCompleted: String?

    /// Variable headline bank picked deterministically from the walk's
    /// minutes + dog id — the user sees a different opener walk-to-walk
    /// rather than the same "X minutes with Luna!" every time. Tier rules:
    ///   * tier 1 (1-19 min)   → "short walk" energy
    ///   * tier 2 (20-44 min)  → "core walk" energy
    ///   * tier 3 (45+ min)    → "long walk" energy
    /// First-ever walks always get the cinematic line regardless of tier.
    var headline: String {
        if isFirstWalk {
            return "\(dogName)'s first walk!"
        }
        let bank = headlineBank(forMinutes: minutes, dogName: dogName)
        var hasher = Hasher()
        hasher.combine(dogID.hashValue)
        hasher.combine(minutes)
        hasher.combine(id)
        let pick = abs(hasher.finalize()) % bank.count
        return bank[pick]
    }

    private func headlineBank(forMinutes minutes: Int, dogName: String) -> [String] {
        if minutes < 20 {
            return [
                "\(minutes) minutes with \(dogName).",
                "Quick one with \(dogName)!",
                "\(dogName) got out. \(minutes) min.",
                "\(minutes) min — better than zero!",
            ]
        } else if minutes < 45 {
            return [
                "\(minutes) minutes with \(dogName)!",
                "\(dogName) just put in \(minutes) min!",
                "Solid \(minutes) min with \(dogName).",
                "\(minutes) min — proper walk!",
                "\(dogName) walked \(minutes) min!",
            ]
        } else {
            return [
                "\(minutes) minutes with \(dogName)!",
                "Big one — \(minutes) min with \(dogName)!",
                "\(minutes) min! \(dogName) is sleeping well tonight.",
                "Properly long walk: \(minutes) min!",
                "\(dogName) got the full \(minutes) min!",
            ]
        }
    }

    /// True when the route bar should render — both fields populated AND a
    /// non-zero total. Lets the overlay collapse cleanly for routeless walks.
    var hasRouteContext: Bool {
        guard let total = routeTotalMinutes, let name = routeName else { return false }
        return total > 0 && !name.isEmpty
    }

    /// 0...1 progress on the active route AT THE MOMENT the walk landed.
    /// Used by the overlay to animate the route bar from old to new.
    var oldFraction: Double {
        guard let total = routeTotalMinutes, total > 0 else { return 0 }
        return min(1, max(0, Double(oldProgressMinutes) / Double(total)))
    }

    var newFraction: Double {
        guard let total = routeTotalMinutes, total > 0 else { return 0 }
        return min(1, max(0, Double(newProgressMinutes) / Double(total)))
    }
}

/// Sendable snapshot of everything needed to enqueue a `PendingWalkComplete`,
/// captured BEFORE a sheet dismiss so the post-dismiss Task doesn't carry
/// `Dog` refs across the dismiss-animation gap. SwiftData objects can vanish
/// (delete, archive, sync race) and reading them off-thread crashes — value
/// types are safe.
struct PendingWalkCompletePayload: Sendable {
    let dogID: PersistentIdentifier
    let dogName: String
    let isFirstWalk: Bool
    let oldProgressMinutes: Int
    let newProgressMinutes: Int
    let routeName: String?
    let routeTotalMinutes: Int?
    let minutesAdded: Int
    let landmarksCrossed: [Landmark]
    let routeCompletedName: String?
    let nextLandmarkName: String?

    func makeEvent(minutes: Int) -> PendingWalkComplete {
        PendingWalkComplete(
            dogID: dogID,
            dogName: dogName,
            minutes: minutes,
            isFirstWalk: isFirstWalk,
            minutesAdded: minutesAdded,
            oldProgressMinutes: oldProgressMinutes,
            newProgressMinutes: newProgressMinutes,
            routeName: routeName,
            routeTotalMinutes: routeTotalMinutes,
            landmarksCrossed: landmarksCrossed,
            nextLandmarkName: nextLandmarkName,
            routeCompleted: routeCompletedName
        )
    }
}
