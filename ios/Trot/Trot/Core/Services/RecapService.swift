import Foundation

/// Weekly recap per `docs/spec.md` → "6. Weekly recap as a fixed ritual":
///   - Total minutes walked
///   - Percentage of needs met across the week
///   - Comparison to last week
///   - Streak status
///   - One personalised insight
///   - A featured photo of the dog
///
/// Pure-function over walk history. "This week" is the trailing 7 days inclusive
/// of today. "Last week" is the 7 days before that. Day boundary is local time
/// per the rest of the app.
enum RecapService {
    static func weekly(
        for dog: Dog,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> WeeklyRecap {
        let walks = dog.walks ?? []
        let target = dog.dailyTargetMinutes
        let todayDay = calendar.startOfDay(for: today)
        let thisWeekStart = calendar.date(byAdding: .day, value: -6, to: todayDay) ?? todayDay
        let lastWeekStart = calendar.date(byAdding: .day, value: -13, to: todayDay) ?? todayDay
        let lastWeekEnd = calendar.date(byAdding: .day, value: -7, to: todayDay) ?? todayDay

        let thisWeek = aggregate(
            walks: walks,
            from: thisWeekStart,
            through: todayDay,
            target: target,
            calendar: calendar
        )
        let lastWeek = aggregate(
            walks: walks,
            from: lastWeekStart,
            through: lastWeekEnd,
            target: target,
            calendar: calendar
        )

        let streak = StreakService.currentStreak(for: dog, today: today, calendar: calendar)

        // Reuse the same observation pipeline as the Insights tab so the recap's
        // featured insight is consistent with what the user already sees.
        let insightsState = InsightsService.state(for: dog, today: today, calendar: calendar)
        let featured = pickFeaturedInsight(from: insightsState.observations)

        return WeeklyRecap(
            thisWeek: thisWeek,
            lastWeek: lastWeek,
            streakDays: streak,
            featuredInsight: featured,
            photo: dog.photo,
            dogName: dog.name
        )
    }

    // MARK: - Auto-show

    /// Sunday-startOfDay of the most recent Sunday in or before `today`.
    /// Used as the per-week key for "have we shown this week's recap yet?"
    static func currentWeekKey(today: Date = .now, calendar: Calendar = .current) -> Date {
        let weekday = calendar.component(.weekday, from: today)  // 1 = Sunday in Gregorian
        let daysSinceSunday = (weekday - 1 + 7) % 7
        let sundayDate = calendar.date(byAdding: .day, value: -daysSinceSunday, to: today) ?? today
        return calendar.startOfDay(for: sundayDate)
    }

    /// True when the user should be auto-presented with the weekly recap on app open.
    /// Conditions per `docs/spec.md` → "6. Weekly recap as a fixed ritual" + Sunday 19:00:
    ///   - Today is Sunday
    ///   - Local time is 19:00 or later
    ///   - This week's recap has not yet been marked seen on this dog
    /// Mon–Sat: never auto-show. The manual entry on Insights remains available.
    static func shouldAutoShow(
        for dog: Dog,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        let weekday = calendar.component(.weekday, from: today)
        guard weekday == 1 else { return false }  // 1 = Sunday
        let hour = calendar.component(.hour, from: today)
        guard hour >= 19 else { return false }
        let weekKey = currentWeekKey(today: today, calendar: calendar)
        return dog.lastRecapSeenWeekStart != weekKey
    }

    /// Mutates `dog` to record that this week's recap has been shown.
    /// Caller is responsible for `modelContext.save()`.
    static func markSeen(
        for dog: Dog,
        today: Date = .now,
        calendar: Calendar = .current
    ) {
        dog.lastRecapSeenWeekStart = currentWeekKey(today: today, calendar: calendar)
    }

    // MARK: - Helpers

    /// Aggregates minutes walked + percent-of-needs-met across an inclusive day range.
    /// Percent-needs-met is the AVERAGE of daily percents capped at 100%, per
    /// `docs/spec.md` → "Daily target with consistency-weighted scoring":
    /// "Going over target does not score higher than hitting it."
    private static func aggregate(
        walks: [Walk],
        from start: Date,
        through end: Date,
        target: Int,
        calendar: Calendar
    ) -> WeekStats {
        guard end >= start else { return .empty }
        var totalMinutes = 0
        var minutesByDay: [Date: Int] = [:]
        for walk in walks {
            let day = calendar.startOfDay(for: walk.startedAt)
            guard day >= start && day <= end else { continue }
            minutesByDay[day, default: 0] += walk.durationMinutes
            totalMinutes += walk.durationMinutes
        }

        let dayCount = (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
        guard target > 0, dayCount > 0 else {
            return WeekStats(totalMinutes: totalMinutes, percentNeedsMet: 0, walkCount: minutesByDay.values.count)
        }

        // Sum of capped daily percents over the day count. Days with no walks contribute 0.
        var summedCappedPercent = 0.0
        var cursor = start
        for _ in 0..<dayCount {
            let dayStart = calendar.startOfDay(for: cursor)
            let minutes = minutesByDay[dayStart] ?? 0
            let dayPercent = min(1.0, Double(minutes) / Double(target))
            summedCappedPercent += dayPercent
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
        }
        let avgPercent = summedCappedPercent / Double(dayCount)

        let walkCount = walks.filter { walk in
            let day = calendar.startOfDay(for: walk.startedAt)
            return day >= start && day <= end
        }.count

        return WeekStats(
            totalMinutes: totalMinutes,
            percentNeedsMet: avgPercent,
            walkCount: walkCount
        )
    }

    /// Prefer the part-of-day pattern (more interesting) over the lifetime summary
    /// for the recap's featured insight. Fallback: nil.
    private static func pickFeaturedInsight(from observations: [Insight]) -> Insight? {
        if let pattern = observations.first(where: { $0.title == "When you walk" }) {
            return pattern
        }
        return observations.first
    }
}

// MARK: - Returned model

struct WeeklyRecap: Equatable, Sendable {
    let thisWeek: WeekStats
    let lastWeek: WeekStats
    let streakDays: Int
    let featuredInsight: Insight?
    let photo: Data?
    let dogName: String

    /// Signed delta in minutes between this-week and last-week totals.
    /// Positive = improved; zero = held steady; negative = down.
    var minutesDelta: Int {
        thisWeek.totalMinutes - lastWeek.totalMinutes
    }

    /// Has this dog been in Trot long enough to compare to a prior week?
    /// If lastWeek has zero data AND zero walks, treat as "no comparison" for copy.
    var hasComparison: Bool {
        lastWeek.totalMinutes > 0 || lastWeek.walkCount > 0
    }
}

struct WeekStats: Equatable, Sendable {
    let totalMinutes: Int
    /// Average daily percent-of-target over the 7 days, capped at 100% per day.
    /// 0.0 to 1.0.
    let percentNeedsMet: Double
    let walkCount: Int

    static let empty = WeekStats(totalMinutes: 0, percentNeedsMet: 0, walkCount: 0)
}
