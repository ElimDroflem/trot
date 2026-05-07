import Foundation

/// First-week milestone ladder per `docs/spec.md` → "0. First-week loop"
/// and `docs/decisions.md` → "First-week milestone ladder — locked", plus
/// streak-tier celebrations matching the 7/14/30-day notification milestones.
///
/// Beats, fired ONCE per dog (ladder + streak tiers):
///   1. firstWalk
///   2. firstHalfTargetDay        — any past day with ≥50% of target walked
///   3. firstFullTargetDay        — any past day with ≥100% of target walked
///   4. first100LifetimeMinutes   — total walk minutes across the dog's life ≥ 100
///   5. first3DayStreak           — StreakService says current streak ≥ 3
///   6. firstWeek                 — today ≥ dog.createdAt + 7 calendar days
///   7. streak7Days               — StreakService says current streak ≥ 7
///   8. streak14Days              — current streak ≥ 14
///   9. streak30Days              — current streak ≥ 30
///
/// In-app moments only — no push notifications. The 7/14/30 streak-milestone
/// push notifications (in `NotificationDecisions`) fire EVERY time those
/// streaks are hit; the in-app celebrations here fire only the first time per dog.
enum MilestoneCode: String, CaseIterable, Sendable {
    case firstWalk
    case firstHalfTargetDay
    case firstFullTargetDay
    case first100LifetimeMinutes
    case first3DayStreak
    case firstWeek
    case streak7Days
    case streak14Days
    case streak30Days

    /// Display order when multiple beats fire in the same check — narrative-first
    /// (the walk happened, then it hit half-target, then full-target, etc.)
    var sortIndex: Int {
        switch self {
        case .firstWalk: return 0
        case .firstHalfTargetDay: return 1
        case .firstFullTargetDay: return 2
        case .first100LifetimeMinutes: return 3
        case .first3DayStreak: return 4
        case .firstWeek: return 5
        case .streak7Days: return 6
        case .streak14Days: return 7
        case .streak30Days: return 8
        }
    }
}

/// Pure-function namespace. No side effects; the caller decides when to persist
/// the fired set onto `Dog.firedMilestones` and when to show celebrations.
enum MilestoneService {
    /// Returns the set of beats whose conditions are met right now,
    /// regardless of whether the dog has already fired them.
    static func eligible(
        for dog: Dog,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> Set<MilestoneCode> {
        var result: Set<MilestoneCode> = []
        let walks = dog.walks ?? []
        let target = dog.dailyTargetMinutes

        if !walks.isEmpty {
            result.insert(.firstWalk)
        }

        let totalMinutes = walks.reduce(0) { $0 + $1.durationMinutes }
        if totalMinutes >= 100 {
            result.insert(.first100LifetimeMinutes)
        }

        if target > 0 {
            let halfTarget = Double(target) / 2.0
            let fullTarget = Double(target)
            var minutesByDay: [Date: Int] = [:]
            for walk in walks {
                let day = calendar.startOfDay(for: walk.startedAt)
                minutesByDay[day, default: 0] += walk.durationMinutes
            }
            for total in minutesByDay.values {
                let totalDouble = Double(total)
                if totalDouble >= halfTarget {
                    result.insert(.firstHalfTargetDay)
                }
                if totalDouble >= fullTarget {
                    result.insert(.firstFullTargetDay)
                }
            }
        }

        let streak = StreakService.currentStreak(for: dog, today: today, calendar: calendar)
        if streak >= 3 { result.insert(.first3DayStreak) }
        if streak >= 7 { result.insert(.streak7Days) }
        if streak >= 14 { result.insert(.streak14Days) }
        if streak >= 30 { result.insert(.streak30Days) }

        let dayDelta = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: dog.createdAt),
            to: calendar.startOfDay(for: today)
        ).day ?? 0
        if dayDelta >= 7 {
            result.insert(.firstWeek)
        }

        return result
    }

    /// Beats eligible to fire AND not already in `dog.firedMilestones`,
    /// returned in narrative sort order so the UI can show them in sequence.
    static func newMilestones(
        for dog: Dog,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> [MilestoneCode] {
        let already = Set(dog.firedMilestones.compactMap(MilestoneCode.init(rawValue:)))
        let eligible = eligible(for: dog, today: today, calendar: calendar)
        return eligible.subtracting(already).sorted { $0.sortIndex < $1.sortIndex }
    }

    /// Mutates `dog` to record that the given codes have now been celebrated.
    /// Caller is responsible for `modelContext.save()`.
    static func markFired(_ codes: [MilestoneCode], on dog: Dog) {
        let existing = Set(dog.firedMilestones)
        let toAdd = codes.map(\.rawValue).filter { !existing.contains($0) }
        guard !toAdd.isEmpty else { return }
        dog.firedMilestones += toAdd
    }
}

// MARK: - Unlock requirement + progress (for the Achievements detail sheet)

/// Current/target progress toward unlocking a milestone. Used by the locked
/// state of the Achievement detail sheet so the user can see "you're 47 of
/// 100 minutes" rather than just "locked." Always represents a count, never
/// a percentage — the view picks the unit string for display.
struct UnlockProgress: Equatable {
    let current: Int
    let target: Int
    /// The thing being measured, e.g. "minutes", "day streak". Singular form;
    /// the view pluralises if needed.
    let unit: String

    var percent: Double {
        guard target > 0 else { return 0 }
        return min(1.0, Double(current) / Double(target))
    }

    var isComplete: Bool { current >= target }
}

extension MilestoneCode {
    /// One-line plain-English unlock requirement. Surfaces in the detail
    /// sheet and is what teases the user toward the next walk.
    var requirement: String {
        switch self {
        case .firstWalk:
            return "Log your first walk."
        case .firstHalfTargetDay:
            return "Hit half of your daily target on any day."
        case .firstFullTargetDay:
            return "Hit your full daily target on any day."
        case .first100LifetimeMinutes:
            return "Reach 100 minutes walked all-time."
        case .first3DayStreak:
            return "Walk three days in a row."
        case .firstWeek:
            return "Use Trot for seven days."
        case .streak7Days:
            return "Walk seven days in a row."
        case .streak14Days:
            return "Walk fourteen days in a row."
        case .streak30Days:
            return "Walk thirty days in a row."
        }
    }

    /// Current progress toward this unlock, calculated from the dog's history.
    /// Mirrors the eligibility logic in `MilestoneService.eligible` so the
    /// progress bar and the unlock event stay in sync — when this returns
    /// `isComplete`, eligibility will fire on the next save.
    func progress(
        for dog: Dog,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> UnlockProgress {
        let walks = dog.walks ?? []
        let totalMinutes = walks.reduce(0) { $0 + $1.durationMinutes }
        let target = max(1, dog.dailyTargetMinutes)
        let streak = StreakService.currentStreak(for: dog, today: today, calendar: calendar)

        switch self {
        case .firstWalk:
            return UnlockProgress(current: min(walks.count, 1), target: 1, unit: "walk")

        case .firstHalfTargetDay:
            let bestDay = bestDayMinutes(walks: walks, calendar: calendar)
            let half = max(1, target / 2)
            return UnlockProgress(current: min(bestDay, half), target: half, unit: "minute")

        case .firstFullTargetDay:
            let bestDay = bestDayMinutes(walks: walks, calendar: calendar)
            return UnlockProgress(current: min(bestDay, target), target: target, unit: "minute")

        case .first100LifetimeMinutes:
            return UnlockProgress(current: min(totalMinutes, 100), target: 100, unit: "minute")

        case .first3DayStreak:
            return UnlockProgress(current: min(streak, 3), target: 3, unit: "day")

        case .firstWeek:
            let days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: dog.createdAt),
                to: calendar.startOfDay(for: today)
            ).day ?? 0
            return UnlockProgress(current: min(days, 7), target: 7, unit: "day on Trot")

        case .streak7Days:
            return UnlockProgress(current: min(streak, 7), target: 7, unit: "day streak")

        case .streak14Days:
            return UnlockProgress(current: min(streak, 14), target: 14, unit: "day streak")

        case .streak30Days:
            return UnlockProgress(current: min(streak, 30), target: 30, unit: "day streak")
        }
    }

    /// Best-day minutes — the highest single-day total across the dog's history.
    /// Used by the half/full-target progress bars so a dog who has walked 60
    /// minutes total spread across 6 days reads as "10/30 minutes" toward the
    /// half-target unlock, not "60/30."
    private func bestDayMinutes(walks: [Walk], calendar: Calendar) -> Int {
        var minutesByDay: [Date: Int] = [:]
        for walk in walks {
            let day = calendar.startOfDay(for: walk.startedAt)
            minutesByDay[day, default: 0] += walk.durationMinutes
        }
        return minutesByDay.values.max() ?? 0
    }
}

// MARK: - Display copy

extension MilestoneCode {
    /// Title in Bricolage Grotesque — short, named, dog-centric.
    func title(dogName: String) -> String {
        switch self {
        case .firstWalk:
            return "\(dogName)'s first walk with Trot."
        case .firstHalfTargetDay:
            return "Halfway there, \(dogName)."
        case .firstFullTargetDay:
            return "\(dogName) hit the target."
        case .first100LifetimeMinutes:
            return "100 minutes walked with \(dogName)."
        case .first3DayStreak:
            return "Three days in a row."
        case .firstWeek:
            return "A week with Trot."
        case .streak7Days:
            return "Seven days in a row."
        case .streak14Days:
            return "Two weeks straight."
        case .streak30Days:
            return "A month of consistency."
        }
    }

    /// One-line subtitle in body type — explanatory, calm.
    func body(dogName: String) -> String {
        switch self {
        case .firstWalk:
            return "A daily habit starts somewhere. Onwards."
        case .firstHalfTargetDay:
            return "Halfway to today's target. The other half is in reach."
        case .firstFullTargetDay:
            return "Today's target met. That's what \(dogName) needed."
        case .first100LifetimeMinutes:
            return "100 logged minutes since you started. Good work."
        case .first3DayStreak:
            return "Three days, three walks. The habit is forming."
        case .firstWeek:
            return "One week on Trot. \(dogName)'s first weekly recap is on the way."
        case .streak7Days:
            return "A whole week of walks logged. \(dogName)'s rhythm is showing."
        case .streak14Days:
            return "Fourteen days. The habit is holding."
        case .streak30Days:
            return "Thirty days. \(dogName) has earned every one."
        }
    }
}
