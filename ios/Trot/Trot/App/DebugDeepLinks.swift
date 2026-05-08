#if DEBUG

import Foundation
import SwiftData

/// Handlers for the `trot://debug/...` URL scheme. Registered in Info.plist
/// (CFBundleURLTypes) and dispatched from `TrotApp.onOpenURL`. Lets test
/// tooling (especially `xcrun simctl openurl booted "trot://..."`) navigate
/// the app and seed state without UI automation.
///
/// All routes are gated behind `#if DEBUG` and never ship in Release. The
/// URL scheme itself stays registered in Release builds (it's harmless), but
/// every call into this enum is compiled out.
///
/// Routes:
/// - `trot://debug/tab/today|journey|insights|dog` — switch tabs
/// - `trot://debug/seed-walks?count=N` — insert N synthetic recent walks for
///   the currently-selected (or first) active dog
/// - `trot://debug/reset` — clear all dogs/walks/windows (gate fires next launch)
/// - `trot://debug/fire-celebration?minutes=N&route=true|false` — fires a
///   walk-complete celebration overlay without logging a walk. Used for
///   QA'ing the overlay visuals in isolation.
enum DebugDeepLinks {
    /// Returns true if the URL was understood and handled. Caller can ignore
    /// the result; logging is internal.
    @discardableResult
    static func handle(
        _ url: URL,
        appState: AppState,
        modelContext: ModelContext
    ) -> Bool {
        guard url.scheme == "trot" else { return false }
        guard let host = url.host, host == "debug" else { return false }

        let segments = url.pathComponents.filter { $0 != "/" }
        guard let first = segments.first else { return false }

        switch first {
        case "tab":
            return handleTab(segments: segments, appState: appState)
        case "seed-walks":
            return handleSeedWalks(url: url, appState: appState, modelContext: modelContext)
        case "reset":
            return handleReset(modelContext: modelContext, appState: appState)
        case "clear-overlays":
            return handleClearOverlays(appState: appState)
        case "fire-celebration":
            return handleFireCelebration(url: url, appState: appState, modelContext: modelContext)
        case "story":
            return handleStory(segments: segments, url: url, appState: appState, modelContext: modelContext)
        case "set-target":
            return handleSetTarget(url: url, modelContext: modelContext)
        default:
            return false
        }
    }

    /// Synthesises a `PendingWalkComplete` and pushes it onto AppState so the
    /// `WalkCompleteOverlay` renders. Doesn't insert a walk — pure visual
    /// QA. `?minutes=42&route=true` drives the headline tier and whether the
    /// route bar shows.
    private static func handleFireCelebration(
        url: URL,
        appState: AppState,
        modelContext: ModelContext
    ) -> Bool {
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let minutesString = comps?.queryItems?.first(where: { $0.name == "minutes" })?.value ?? "42"
        let minutes = max(1, Int(minutesString) ?? 42)
        let withRoute = (comps?.queryItems?.first(where: { $0.name == "route" })?.value ?? "true") == "true"

        guard let dog = firstActiveDog(in: modelContext) else { return false }

        let dogName = dog.name.isEmpty ? "Your dog" : dog.name
        let routeName: String? = withRoute ? "Finding your rhythm" : nil
        let routeTotal: Int? = withRoute ? 240 : nil
        let event = PendingWalkComplete(
            dogID: dog.persistentModelID,
            dogName: dogName,
            minutes: minutes,
            isFirstWalk: false,
            minutesAdded: withRoute ? minutes : 0,
            oldProgressMinutes: withRoute ? 60 : 0,
            newProgressMinutes: withRoute ? min(60 + minutes, 240) : 0,
            routeName: routeName,
            routeTotalMinutes: routeTotal,
            landmarksCrossed: [],
            nextLandmarkName: nil,
            routeCompleted: nil
        )
        appState.pendingWalkCompletes.append(event)
        return true
    }

    /// Drains all pending celebration / walk-complete / recap overlays. Useful
    /// when test tooling deep-links into a tab and the queued overlays from
    /// DebugSeed (e.g. firstWalk milestone) would otherwise cover the screen.
    private static func handleClearOverlays(appState: AppState) -> Bool {
        appState.pendingCelebrations.removeAll()
        appState.pendingWalkCompletes.removeAll()
        appState.pendingRecapDogID = nil
        return true
    }

    private static func handleTab(segments: [String], appState: AppState) -> Bool {
        guard segments.count >= 2 else { return false }
        guard let tab = TrotTab(rawValue: segments[1]) else { return false }
        appState.debugGateBypassed = true  // ensure we get past the sign-in gate
        appState.selectedTab = tab
        // Tab navigation deep-links are exclusively a testing affordance — drain
        // any queued overlays so the simulator screenshot shows the tab itself.
        appState.pendingCelebrations.removeAll()
        appState.pendingWalkCompletes.removeAll()
        appState.pendingRecapDogID = nil
        return true
    }

    private static func handleSeedWalks(
        url: URL,
        appState: AppState,
        modelContext: ModelContext
    ) -> Bool {
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let countString = comps?.queryItems?.first(where: { $0.name == "count" })?.value ?? "5"
        let count = max(1, min(60, Int(countString) ?? 5))

        guard let dog = firstActiveDog(in: modelContext) else { return false }

        let calendar = Calendar.current
        let now = Date()
        for offset in 0..<count {
            // Spread walks across the last `count` days, one per day, late afternoon.
            guard let dayStart = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            guard let walkTime = calendar.date(bySettingHour: 16, minute: 30, second: 0, of: dayStart) else { continue }
            let walk = Walk(
                startedAt: walkTime,
                durationMinutes: Int.random(in: 25...55),
                distanceMeters: nil,
                source: .manual,
                notes: "",
                dogs: [dog]
            )
            modelContext.insert(walk)
        }
        try? modelContext.save()
        appState.selectedDogID = dog.persistentModelID
        return true
    }

    private static func handleReset(modelContext: ModelContext, appState: AppState) -> Bool {
        let dogs = (try? modelContext.fetch(FetchDescriptor<Dog>())) ?? []
        let walks = (try? modelContext.fetch(FetchDescriptor<Walk>())) ?? []
        let windows = (try? modelContext.fetch(FetchDescriptor<WalkWindow>())) ?? []
        for w in walks { modelContext.delete(w) }
        for w in windows { modelContext.delete(w) }
        for d in dogs { modelContext.delete(d) }
        try? modelContext.save()
        appState.selectedDogID = nil
        appState.selectedTab = .today
        return true
    }

    /// Story-tab QA helpers. Two routes:
    ///   - `trot://debug/story/wipe` — deletes the active dog's story so
    ///     the genre picker re-appears.
    ///   - `trot://debug/story/set-genre?name=fantasy` — flips the active
    ///     story to a different genre (preserving chapters/pages) so the
    ///     six genre treatments can be screenshot-cycled without
    ///     re-seeding.
    private static func handleStory(
        segments: [String],
        url: URL,
        appState: AppState,
        modelContext: ModelContext
    ) -> Bool {
        guard segments.count >= 2 else { return false }
        guard let dog = firstActiveDog(in: modelContext) else { return false }
        appState.debugGateBypassed = true
        appState.selectedDogID = dog.persistentModelID
        appState.selectedTab = .story
        appState.pendingCelebrations.removeAll()
        appState.pendingWalkCompletes.removeAll()
        appState.pendingRecapDogID = nil

        switch segments[1] {
        case "wipe":
            if let story = dog.story {
                modelContext.delete(story)
                dog.story = nil
                try? modelContext.save()
            }
            return true
        case "set-genre":
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let raw = comps?.queryItems?.first(where: { $0.name == "name" })?.value ?? ""
            guard let genre = StoryGenre(rawValue: raw) else { return false }
            if let story = dog.story {
                story.genre = genre
                // Mark every closed chapter as already-seen so the
                // chapter-close celebration overlay doesn't keep firing
                // when we cycle genres for QA — its seen key is keyed by
                // the chapter's persistentModelID.hashValue.
                for chapter in (story.chapters ?? []) where chapter.closedAt != nil {
                    UserDefaults.standard.set(
                        true,
                        forKey: "trot.story.chapterSeen.\(chapter.persistentModelID.hashValue)"
                    )
                }
                try? modelContext.save()
            }
            return true
        default:
            return false
        }
    }

    /// `trot://debug/set-target?minutes=200` — bumps the active dog's
    /// `dailyTargetMinutes` so the Story-tab milestone gating can be
    /// QA-cycled without manually walking the simulator dog. Also
    /// useful for testing how Today/Insights handle very-high targets.
    private static func handleSetTarget(
        url: URL,
        modelContext: ModelContext
    ) -> Bool {
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let raw = comps?.queryItems?.first(where: { $0.name == "minutes" })?.value ?? ""
        guard let minutes = Int(raw), minutes > 0, minutes <= 600 else { return false }
        guard let dog = firstActiveDog(in: modelContext) else { return false }
        dog.dailyTargetMinutes = minutes
        try? modelContext.save()
        return true
    }

    private static func firstActiveDog(in context: ModelContext) -> Dog? {
        let predicate = #Predicate<Dog> { $0.archivedAt == nil }
        let descriptor = FetchDescriptor<Dog>(predicate: predicate, sortBy: [SortDescriptor(\.createdAt)])
        return try? context.fetch(descriptor).first
    }
}

#endif
