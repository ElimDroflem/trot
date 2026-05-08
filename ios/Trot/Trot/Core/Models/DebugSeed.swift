#if DEBUG
import Foundation
import SwiftData

/// First-launch demo data for DEBUG builds. Seeds Luna + a 7-day backdrop of
/// walks so every surface (Today ring, Insights, Daily rhythm, Streak, Journey
/// progress, Achievements) has data to say something *real* on the first
/// screenshot — a single seeded walk made averages look broken (one 42-min
/// walk → "averaging 6 min/day").
///
/// Synthetic walks are marked with the `Self.syntheticNotesTag` in `notes` so
/// the Profile → Debug Tools "Wipe synthetic walks" affordance can remove only
/// the seed data without touching real user logs. The tag is intentionally a
/// short bracketed sentinel — it stays out of UI display (notes are blank in
/// the seed) and is trivial to filter on.
enum DebugSeed {
    /// Sentinel written into `Walk.notes` for every synthetic walk. The wipe
    /// affordance filters on this exact prefix; never reuse for real walks.
    static let syntheticNotesTag = "[debug-seed]"

    @MainActor
    static func seedIfEmpty(container: ModelContainer) {
        let context = container.mainContext

        let existing = (try? context.fetchCount(FetchDescriptor<Dog>())) ?? 0
        guard existing == 0 else { return }

        let calendar = Calendar(identifier: .gregorian)
        let dob = calendar.date(byAdding: .year, value: -3, to: .now)
            ?? Date(timeIntervalSince1970: 0)

        let luna = Dog(
            name: "Luna",
            breedPrimary: "Beagle",
            dateOfBirth: dob,
            weightKg: 12,
            sex: .female,
            isNeutered: true,
            activityLevel: .moderate,
            dailyTargetMinutes: 60
        )
        luna.llmRationale = "Beagles do best with a second walk before sundown."

        context.insert(luna)

        let morning = WalkWindow(slot: .earlyMorning, enabled: true, dog: luna)
        let evening = WalkWindow(slot: .evening, enabled: true, dog: luna)
        context.insert(morning)
        context.insert(evening)

        // 6 walks across the past 7 days — one rest day (3 days ago) so the
        // streak is interesting but unbroken (rolling 7-day window allows one
        // rest). Hours mix morning/lunchtime/evening so the Daily Rhythm
        // chart has visible distribution.
        let entries: [(daysAgo: Int, hour: Int, duration: Int)] = [
            (6, 7,  38),   // a week ago, morning
            (5, 18, 50),   // 5 days ago, evening
            (4, 8,  32),   // 4 days ago, morning
            // (3, ...) — rest day
            (2, 12, 25),   // 2 days ago, lunchtime
            (1, 7,  55),   // yesterday, morning
            (0, 8,  35),   // today, morning (clamped to never be in the future)
        ]

        var totalSeededMinutes = 0
        for entry in entries {
            guard let day = calendar.date(byAdding: .day, value: -entry.daysAgo, to: .now) else { continue }
            let dayStart = calendar.startOfDay(for: day)
            let target = calendar.date(bySettingHour: entry.hour, minute: 0, second: 0, of: dayStart) ?? dayStart
            // Today's morning walk would land in the future for an early-AM
            // launch — clamp to "1 minute ago" so we never produce a future
            // walk (DatePicker rejects them on edit, and streak math gets
            // confused).
            let oneMinuteAgo = Date.now.addingTimeInterval(-60)
            let walkStart = min(target, oneMinuteAgo)

            let walk = Walk(
                startedAt: walkStart,
                durationMinutes: entry.duration,
                distanceMeters: estimatedDistance(forMinutes: entry.duration),
                source: .passive,
                notes: syntheticNotesTag,
                dogs: [luna]
            )
            context.insert(walk)
            totalSeededMinutes += entry.duration
        }

        // Apply the lifetime seed minutes to Luna's active route so the
        // Journey tab reflects the same walk history as Today/Insights.
        // Without this, route progress stays at zero while Highlights happily
        // shows "6 walks · 3h 55m" — the data inconsistency the user reported.
        // We don't keep the WalkApplication result — landmark celebrations
        // belong to real walks, not lived-in seed.
        _ = JourneyService.applyWalk(minutes: totalSeededMinutes, to: luna)

        // Pre-mark milestones the seed walks already satisfy so the user
        // doesn't see "Luna's first walk" overlay every fresh debug install
        // — Luna here is a lived-in dog with a 6-walk history, not a
        // brand-new pup. Real first-time users hit these celebrations the
        // honest way (logging their first walk).
        let preFired: [MilestoneCode] = [
            .firstWalk,
            .firstHalfTargetDay,
            .firstFullTargetDay,  // covered by 50-min walk vs 60-min target
            .first100LifetimeMinutes,
            .first3DayStreak,
            .firstWeek,
        ]
        luna.firedMilestones = preFired.map(\.rawValue)

        do {
            try context.save()
        } catch {
            print("DebugSeed save failed: \(error)")
        }
    }

    /// Removes every synthetic walk from the store (filtered by the
    /// `syntheticNotesTag` sentinel). Leaves real user-logged walks alone.
    /// Returns the number deleted so the caller can report it.
    @MainActor
    @discardableResult
    static func wipeSyntheticWalks(in context: ModelContext) -> Int {
        // The #Predicate macro can't reference a static let on a non-Model
        // type, so capture the tag in a local first.
        let tag = syntheticNotesTag
        let predicate = #Predicate<Walk> { $0.notes == tag }
        let descriptor = FetchDescriptor<Walk>(predicate: predicate)
        let synthetic = (try? context.fetch(descriptor)) ?? []
        for walk in synthetic { context.delete(walk) }
        try? context.save()
        return synthetic.count
    }

    /// Counts synthetic walks for the Debug Tools card banner.
    @MainActor
    static func syntheticWalkCount(in context: ModelContext) -> Int {
        let tag = syntheticNotesTag
        let predicate = #Predicate<Walk> { $0.notes == tag }
        let descriptor = FetchDescriptor<Walk>(predicate: predicate)
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    /// Rough pedometer-style distance estimate so the seed walks have non-nil
    /// distance values (the Activity tab and lifetime totals look bare without
    /// them). ~70 m/min average walking pace. Real walks come from HealthKit's
    /// `distanceWalkingRunning` which is materially more accurate.
    private static func estimatedDistance(forMinutes minutes: Int) -> Double {
        Double(minutes) * 70.0
    }
}
#endif
