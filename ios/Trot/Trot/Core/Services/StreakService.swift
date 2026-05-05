import Foundation

/// Pure-function streak math per `docs/decisions.md`:
///   - Day boundary = local time (caller-supplied calendar).
///   - HIT day = ≥50% of `dog.dailyTargetMinutes` walked.
///   - PARTIAL = >0 but <50%; does not extend streak count, burns rest-day allowance.
///   - MISS = 0 minutes; does not extend streak count, burns rest-day allowance.
///   - Within any 7-consecutive-day stretch of the streak run, at most 1 non-hit is allowed.
///   - 2+ non-hits in any 7-day stretch of the run breaks the streak.
///   - Streak count = number of HIT days in the run.
///   - Days before `dog.createdAt` aren't part of the run (no penalty for not-yet-existing).
///
/// No side effects, no I/O. Safe to call from any context.
enum StreakService {
    static func currentStreak(
        for dog: Dog,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let target = dog.dailyTargetMinutes
        guard target > 0 else { return 0 }
        let halfTarget = Double(target) / 2.0

        let walks = dog.walks ?? []
        guard !walks.isEmpty else { return 0 }

        var minutesByDay: [Date: Int] = [:]
        for walk in walks {
            let day = calendar.startOfDay(for: walk.startedAt)
            minutesByDay[day, default: 0] += walk.durationMinutes
        }

        let todayDay = calendar.startOfDay(for: today)
        let earliestDay = calendar.startOfDay(for: dog.createdAt)

        var streak = 0
        var cursor = todayDay
        var nonHitDaysInRun: [Date] = []   // already-processed non-hit days, most recent first

        while cursor >= earliestDay {
            let minutes = minutesByDay[cursor] ?? 0
            let isHit = Double(minutes) >= halfTarget

            // Count non-hits in the last 6 days of the run (those within 6 calendar days of cursor).
            // Combined with the cursor itself if it's a non-hit, that's the count for the trailing
            // 7-day window of the streak run ending at cursor.
            let recentNonHits = nonHitDaysInRun.filter { day in
                let diff = calendar.dateComponents([.day], from: cursor, to: day).day ?? 0
                return diff <= 6
            }.count

            let totalNonHits = recentNonHits + (isHit ? 0 : 1)
            if totalNonHits > 1 { break }   // streak run can't extend past cursor

            if isHit {
                streak += 1
            } else {
                nonHitDaysInRun.insert(cursor, at: 0)
            }

            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previousDay
        }

        return streak
    }
}
