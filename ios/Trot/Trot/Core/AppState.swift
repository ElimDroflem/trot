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

    /// DEBUG-only counter the Profile → Debug Tools "Restart onboarding"
    /// button bumps after wiping data + resetting the persisted flags.
    /// `RootView` observes the change and flips `hasContinued` back to
    /// false so the user lands on the gate, ready to re-run the new
    /// onboarding flow end-to-end. Same signal fires from
    /// `trot://debug/reset`.
    var debugRestartCounter: Int = 0

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
        // -DebugCelebrationMinutes N [-DebugCelebrationUnlock page1|page2]
        // → enqueue a synthetic walk-complete event so the
        // WalkCompleteOverlay renders on first paint. Used by simulator
        // testing to QA the overlay without firing a real walk save
        // (which requires UI driving the LogWalkSheet or ExpeditionView).
        // The dog ID is filled in lazily by RootView once active dogs
        // are queried.
        let celebrationMinutes = defaults.integer(forKey: "DebugCelebrationMinutes")
        if celebrationMinutes > 0 {
            pendingDebugCelebrationMinutes = celebrationMinutes
            switch defaults.string(forKey: "DebugCelebrationUnlock") ?? "" {
            case "page1": pendingDebugCelebrationUnlock = .page1
            case "page2": pendingDebugCelebrationUnlock = .page2
            default:      pendingDebugCelebrationUnlock = .none
            }
        }
    }

    /// Captured launch-arg state for the synthetic celebration. RootView
    /// reads these once active dogs are available, builds the event, and
    /// clears.
    var pendingDebugCelebrationMinutes: Int?
    var pendingDebugCelebrationUnlock: DebugCelebrationUnlock = .none

    /// Which milestone the synthetic celebration should claim was crossed
    /// (drives the PAGE UNLOCKED stamp). `.none` renders just the bar
    /// advance.
    enum DebugCelebrationUnlock {
        case none
        case page1
        case page2
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

    /// Append a walk-complete event for a walk that was just saved. Carries
    /// the snapshot the `WalkCompleteOverlay` needs to render *story-mode*
    /// progress: minutes-today before/after this walk, the dog's daily
    /// target, and how many story pages the user has already generated
    /// today. From those, the overlay draws the progress bar with notches
    /// at half- and full-target, the next-page caption, and the
    /// PAGE UNLOCKED stamp when this walk crossed a milestone.
    func enqueueWalkComplete(
        dog: Dog,
        minutes: Int,
        isFirstWalk: Bool,
        oldMinutesToday: Int,
        newMinutesToday: Int,
        targetMinutes: Int,
        pagesAlreadyToday: Int
    ) {
        let event = PendingWalkComplete(
            dogID: dog.persistentModelID,
            dogName: dog.name.isEmpty ? "Your dog" : dog.name,
            minutes: minutes,
            isFirstWalk: isFirstWalk,
            oldMinutesToday: oldMinutesToday,
            newMinutesToday: newMinutesToday,
            targetMinutes: targetMinutes,
            pagesAlreadyToday: pagesAlreadyToday
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
/// needs to render: dopamine headline + story-mode progress bar + (when
/// crossed) PAGE UNLOCKED stamp.
///
/// Story-mode progress is computed from `oldMinutesToday`, `newMinutesToday`,
/// `targetMinutes`, and `pagesAlreadyToday`:
///   - bar fills from old/target → new/target with notches at 0.5 and 1.0
///   - "X min to today's first/second page" caption derived from current vs
///     half- vs full-target thresholds
///   - PAGE 1 / PAGE 2 UNLOCKED stamps fire when this walk crossed the
///     half- or full-target line
///
/// Replaced May 2026 — earlier shape carried route name, route total, and
/// landmark stamps from the old Journey-mode progression. That whole
/// concept has been removed; story milestones now own post-walk progress.
struct PendingWalkComplete: Identifiable, Sendable {
    let id = UUID()
    /// The dog that was walked. Carried through so `WalkCompleteOverlay` can
    /// fetch a dog-voice line from `LLMService` without re-resolving from a
    /// query.
    let dogID: PersistentIdentifier
    let dogName: String
    /// Duration of the walk that just landed.
    let minutes: Int
    /// True when this was the dog's first-ever logged walk. Used to push the
    /// LLM toward a more cinematic post-walk line. The visual milestone
    /// celebration for "first walk" rides on top via `MilestoneService`.
    let isFirstWalk: Bool
    /// Minutes the dog had walked today BEFORE this save.
    let oldMinutesToday: Int
    /// Minutes the dog has walked today AFTER this save (= old + this walk's
    /// duration, clamped to 0).
    let newMinutesToday: Int
    /// Dog's daily target. Drives the bar's full width and the half/full
    /// milestone notches.
    let targetMinutes: Int
    /// Story pages already generated today before this walk's save. 0, 1,
    /// or 2 — the daily cap is two. Used by the overlay's caption to
    /// distinguish "first page coming" from "second page coming" from
    /// "back tomorrow."
    let pagesAlreadyToday: Int

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

    // MARK: - Story-mode progress derivations

    /// Half the daily target, clamped >= 1. Drives the page-1 notch and the
    /// "X min to today's first page" caption.
    var halfTargetMinutes: Int { max(1, targetMinutes / 2) }

    /// Bar fraction (0...1) at the moment of save — capped at full-target.
    var oldFraction: Double { fraction(for: oldMinutesToday) }
    var newFraction: Double { fraction(for: newMinutesToday) }

    private func fraction(for minutes: Int) -> Double {
        guard targetMinutes > 0 else { return 0 }
        return min(1, max(0, Double(minutes) / Double(targetMinutes)))
    }

    /// True if this walk pushed the user from below half-target to at-or-
    /// above. Drives the PAGE 1 UNLOCKED stamp on the celebration overlay.
    var crossedHalfTarget: Bool {
        oldMinutesToday < halfTargetMinutes && newMinutesToday >= halfTargetMinutes
    }

    /// True if this walk pushed the user from below full-target to at-or-
    /// above AND there was already a page generated today (so the user is
    /// crossing into page-2 territory, not just "100% target reached for
    /// the first page"). Drives the PAGE 2 UNLOCKED stamp.
    var crossedFullTarget: Bool {
        oldMinutesToday < targetMinutes
            && newMinutesToday >= targetMinutes
            && pagesAlreadyToday >= 1
    }

    /// What the celebration's progress caption should say. Branches on the
    /// post-save state — minutes still under half / between half and full /
    /// at-or-over full / cap hit. Phrased as one tight sentence each.
    var progressCaption: String {
        if pagesAlreadyToday >= 2 || (pagesAlreadyToday >= 1 && newMinutesToday >= targetMinutes) {
            return "Two pages today. The book waits for tomorrow."
        }
        if newMinutesToday < halfTargetMinutes {
            let needed = halfTargetMinutes - newMinutesToday
            return "\(needed) min to today's first page."
        }
        if newMinutesToday < targetMinutes {
            let needed = targetMinutes - newMinutesToday
            return "\(needed) min to today's second page."
        }
        // At-or-over full target with 0 pages today (single big walk that
        // crossed both thresholds). The user can pick page 1 *and* page 2
        // back-to-back on the Story tab.
        return "Both of today's pages are ready."
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
    let oldMinutesToday: Int
    let newMinutesToday: Int
    let targetMinutes: Int
    let pagesAlreadyToday: Int

    func makeEvent(minutes: Int) -> PendingWalkComplete {
        PendingWalkComplete(
            dogID: dogID,
            dogName: dogName,
            minutes: minutes,
            isFirstWalk: isFirstWalk,
            oldMinutesToday: oldMinutesToday,
            newMinutesToday: newMinutesToday,
            targetMinutes: targetMinutes,
            pagesAlreadyToday: pagesAlreadyToday
        )
    }
}
