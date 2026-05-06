import Foundation

/// Personalised observations from walk history, plus a "Trot is learning Luna's
/// patterns" progress state for the first 7 days per `docs/spec.md` → "First-week loop":
/// "Anticipation is part of the loop, not a placeholder."
///
/// Pure function over walk history + dog state. No I/O, no side effects.
enum InsightsService {
    /// Number of days of walk-history data Trot considers "enough to read patterns."
    /// Below this, the Insights tab shows a learning state alongside any thin observations.
    static let learningTarget: Int = 7

    static func state(
        for dog: Dog,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> InsightsState {
        let walks = dog.walks ?? []
        let days = daysWithTrot(dog: dog, today: today, calendar: calendar)
        let learning = days < learningTarget
            ? LearningProgress(daysOfData: days, target: learningTarget)
            : nil

        let observations = computeObservations(
            walks: walks,
            today: today,
            calendar: calendar,
            daysWithTrot: days
        )

        return InsightsState(learning: learning, observations: observations)
    }

    // MARK: - Helpers

    /// Inclusive: a brand-new dog created today has 1 day with Trot.
    private static func daysWithTrot(dog: Dog, today: Date, calendar: Calendar) -> Int {
        let createdDay = calendar.startOfDay(for: dog.createdAt)
        let todayDay = calendar.startOfDay(for: today)
        let delta = calendar.dateComponents([.day], from: createdDay, to: todayDay).day ?? 0
        return max(1, delta + 1)
    }

    private static func computeObservations(
        walks: [Walk],
        today: Date,
        calendar: Calendar,
        daysWithTrot: Int
    ) -> [Insight] {
        guard !walks.isEmpty else { return [] }
        var insights: [Insight] = []

        // Lifetime summary — defensible from 1 walk, builds emotional weight as it grows.
        let totalMinutes = walks.reduce(0) { $0 + $1.durationMinutes }
        let walkCount = walks.count
        insights.append(
            Insight(
                title: "Lifetime walks",
                body: walkCount == 1
                    ? "1 walk logged, \(totalMinutes) minutes."
                    : "\(walkCount) walks logged, \(totalMinutes) minutes total."
            )
        )

        // Part-of-day pattern — only surfaced when one bucket dominates with ≥3 walks.
        if let dominant = dominantPartOfDay(walks: walks, calendar: calendar) {
            insights.append(
                Insight(
                    title: "When you walk",
                    body: "Most walks happen in the \(dominant.label). \(dominant.share)% so far."
                )
            )
        }

        // Weekly trend — needs at least 7 days of data so the comparison isn't noise.
        if daysWithTrot >= 7,
           let trend = weeklyTrend(walks: walks, today: today, calendar: calendar) {
            insights.append(trend)
        }

        // Weekday/weekend pattern — needs ≥14 days of data for the split to mean something.
        if daysWithTrot >= 14,
           let split = weekdayWeekendSplit(walks: walks, today: today, calendar: calendar) {
            insights.append(split)
        }

        // Favorite hour — needs ≥7 walks so a "usual hour" is more than coincidence.
        if walks.count >= 7,
           let hour = favoriteHour(walks: walks, calendar: calendar) {
            insights.append(hour)
        }

        return insights
    }

    /// This week (trailing 7 days inclusive) vs last week (the 7 days before).
    /// Skips when there's nothing to compare to (last week empty).
    private static func weeklyTrend(
        walks: [Walk],
        today: Date,
        calendar: Calendar
    ) -> Insight? {
        let todayDay = calendar.startOfDay(for: today)
        let thisStart = calendar.date(byAdding: .day, value: -6, to: todayDay) ?? todayDay
        let lastStart = calendar.date(byAdding: .day, value: -13, to: todayDay) ?? todayDay
        let lastEnd = calendar.date(byAdding: .day, value: -7, to: todayDay) ?? todayDay

        let thisMinutes = minutesBetween(walks: walks, from: thisStart, through: todayDay, calendar: calendar)
        let lastMinutes = minutesBetween(walks: walks, from: lastStart, through: lastEnd, calendar: calendar)
        guard lastMinutes > 0 else { return nil }

        let delta = thisMinutes - lastMinutes
        let body: String
        if delta > 0 {
            body = "\(thisMinutes) minutes this week, \(delta) more than last."
        } else if delta < 0 {
            body = "\(thisMinutes) minutes this week, \(abs(delta)) fewer than last."
        } else {
            body = "\(thisMinutes) minutes this week. Same as last."
        }
        return Insight(title: "Weekly trend", body: body)
    }

    private static func minutesBetween(
        walks: [Walk],
        from start: Date,
        through end: Date,
        calendar: Calendar
    ) -> Int {
        walks.reduce(0) { acc, walk in
            let day = calendar.startOfDay(for: walk.startedAt)
            return (day >= start && day <= end) ? acc + walk.durationMinutes : acc
        }
    }

    /// Weekday vs weekend split. Surfaces only when one side averages clearly more
    /// minutes per day (≥30% lift over the other) — a thin lead isn't an insight.
    private static func weekdayWeekendSplit(
        walks: [Walk],
        today: Date,
        calendar: Calendar
    ) -> Insight? {
        var weekdayMinutes = 0
        var weekendMinutes = 0
        for walk in walks {
            let weekday = calendar.component(.weekday, from: walk.startedAt)  // 1=Sun, 7=Sat
            if weekday == 1 || weekday == 7 {
                weekendMinutes += walk.durationMinutes
            } else {
                weekdayMinutes += walk.durationMinutes
            }
        }
        // Average over the 5 weekdays vs 2 weekend days for a fair-per-day comparison.
        let weekdayPerDay = Double(weekdayMinutes) / 5.0
        let weekendPerDay = Double(weekendMinutes) / 2.0
        guard weekdayPerDay > 0 || weekendPerDay > 0 else { return nil }

        let bigger = max(weekdayPerDay, weekendPerDay)
        let smaller = min(weekdayPerDay, weekendPerDay)
        guard smaller == 0 || bigger / smaller >= 1.3 else { return nil }

        let lift = smaller == 0 ? 100 : Int(round((bigger - smaller) / smaller * 100))
        if weekendPerDay > weekdayPerDay {
            return Insight(
                title: "Weekday vs weekend",
                body: "\(lift)% more minutes on weekend days than weekdays, on average."
            )
        }
        return Insight(
            title: "Weekday vs weekend",
            body: "\(lift)% more minutes on weekdays than weekends, on average."
        )
    }

    /// Hour-of-day bucket where the most walks start. Surfaces only when one hour
    /// has ≥40% of walks — otherwise it's "you walk at all sorts of times."
    private static func favoriteHour(
        walks: [Walk],
        calendar: Calendar
    ) -> Insight? {
        var byHour: [Int: Int] = [:]
        for walk in walks {
            let hour = calendar.component(.hour, from: walk.startedAt)
            byHour[hour, default: 0] += 1
        }
        guard let top = byHour.max(by: { $0.value < $1.value }) else { return nil }
        let share = Double(top.value) / Double(walks.count)
        guard share >= 0.4 else { return nil }
        return Insight(
            title: "Favorite hour",
            body: "Most walks start around \(formatHour(top.key)). \(Int(round(share * 100)))% so far."
        )
    }

    /// 24h hour to a readable 12h string ("8am", "6pm", "noon", "midnight").
    private static func formatHour(_ hour: Int) -> String {
        switch hour {
        case 0: return "midnight"
        case 12: return "noon"
        case 1...11: return "\(hour)am"
        default: return "\(hour - 12)pm"
        }
    }

    private static func dominantPartOfDay(
        walks: [Walk],
        calendar: Calendar
    ) -> (label: String, share: Int)? {
        guard walks.count >= 3 else { return nil }
        var buckets: [PartOfDay: Int] = [:]
        for walk in walks {
            buckets[partOfDay(for: walk.startedAt, calendar: calendar), default: 0] += 1
        }
        let total = buckets.values.reduce(0, +)
        guard total > 0,
              let top = buckets.max(by: { $0.value < $1.value }) else { return nil }
        let share = Int(round(Double(top.value) / Double(total) * 100))
        guard share >= 50 else { return nil }
        return (top.key.label, share)
    }

    private enum PartOfDay: Hashable {
        case morning, afternoon, evening, night

        var label: String {
            switch self {
            case .morning: return "morning"
            case .afternoon: return "afternoon"
            case .evening: return "evening"
            case .night: return "night"
            }
        }
    }

    private static func partOfDay(for date: Date, calendar: Calendar) -> PartOfDay {
        switch calendar.component(.hour, from: date) {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<22: return .evening
        default: return .night
        }
    }
}

// MARK: - Returned model

struct InsightsState: Equatable, Sendable {
    let learning: LearningProgress?
    let observations: [Insight]
}

struct LearningProgress: Equatable, Sendable {
    let daysOfData: Int
    let target: Int

    var fraction: Double {
        guard target > 0 else { return 1 }
        return min(1, max(0, Double(daysOfData) / Double(target)))
    }

    var remainingDays: Int {
        max(0, target - daysOfData)
    }
}

struct Insight: Equatable, Identifiable, Sendable {
    let title: String
    let body: String

    var id: String { title + body }
}
