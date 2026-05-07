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
        default:
            return false
        }
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

    private static func firstActiveDog(in context: ModelContext) -> Dog? {
        let predicate = #Predicate<Dog> { $0.archivedAt == nil }
        let descriptor = FetchDescriptor<Dog>(predicate: predicate, sortBy: [SortDescriptor(\.createdAt)])
        return try? context.fetch(descriptor).first
    }
}

#endif
