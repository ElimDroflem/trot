import Foundation

/// Real, owner-facing insights about a specific dog. Combines walk-pattern
/// data with breed-target knowledge, life-stage rules, and health flags. No
/// LLM — every line is templated and deterministic, so it's free, fast,
/// can't fail mid-render, and is testable as a pure function.
///
/// Replaces the old "Luna says" LLM card on Insights, which pretended the
/// dog was an analyst. Insights belongs to the owner; the dog-voice surface
/// lives on the Home tab in `DogChatCard`.
///
/// Output is a small ordered list of `DogInsight`. The `Insights` tab
/// renders the top 1-3 — selection is by relevance: under-target volume
/// before lifestyle pattern before generic trend.
struct DogInsight: Identifiable, Equatable {
    let id: String
    let kind: Kind
    let title: String
    let body: String

    enum Kind: String, Sendable {
        case volume       // breed-target × actual minutes
        case lifeStage    // puppy/adult/senior advice tied to walking pattern
        case health       // arthritis / brachy / hip-dysplasia
        case timeOfDay    // strong time-of-day pattern
        case trend        // week-over-week trend
        case streak       // current streak observation
    }
}

enum DogInsightsService {
    /// Top three insights for this dog, ordered by relevance. Empty for a
    /// brand-new dog with no walks (the learning state on the view handles
    /// the empty UI; here we just don't pretend to have insight).
    static func insights(
        for dog: Dog,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [DogInsight] {
        let walks = dog.walks ?? []
        guard !walks.isEmpty else { return [] }

        var pool: [DogInsight] = []

        if let volume = volumeInsight(for: dog, walks: walks, now: now, calendar: calendar) {
            pool.append(volume)
        }
        if let stage = lifeStageInsight(for: dog, walks: walks, now: now, calendar: calendar) {
            pool.append(stage)
        }
        pool.append(contentsOf: healthInsights(for: dog, walks: walks))
        if let tod = timeOfDayInsight(for: dog, walks: walks, calendar: calendar) {
            pool.append(tod)
        }
        if let trend = trendInsight(for: dog, walks: walks, now: now, calendar: calendar) {
            pool.append(trend)
        }
        if let streak = streakInsight(for: dog, now: now, calendar: calendar) {
            pool.append(streak)
        }

        // Cap at three so the section stays scannable. Volume / health /
        // life-stage already sort to the top via the order they were appended.
        return Array(pool.prefix(3))
    }

    // MARK: - Volume vs breed target

    /// "Beagles need 60-90 min daily. You're averaging 45 — room to grow."
    /// Anchors the dog's average against the breed-table target. Tells the
    /// owner whether they're over, on track, or under, and by how much.
    private static func volumeInsight(
        for dog: Dog,
        walks: [Walk],
        now: Date,
        calendar: Calendar
    ) -> DogInsight? {
        let target = dog.dailyTargetMinutes
        guard target > 0 else { return nil }
        let avg = recentDailyAverage(walks: walks, now: now, calendar: calendar)
        guard avg > 0 else { return nil }

        let breed = dog.breedPrimary.isEmpty ? "Dogs your dog's size" : "\(dog.breedPrimary)s"
        let dogName = dog.name

        if avg < Int(Double(target) * 0.7) {
            let gap = target - avg
            return DogInsight(
                id: "volume.under",
                kind: .volume,
                title: "Room to walk more",
                body: "\(breed) at \(dogName)'s stage do well around \(target) min a day. \(dogName) is averaging \(avg). \(gap) min more would close the gap."
            )
        } else if avg > Int(Double(target) * 1.4) {
            return DogInsight(
                id: "volume.over",
                kind: .volume,
                title: "Plenty of mileage",
                body: "\(dogName) is averaging \(avg) min a day, well above the typical \(target) for \(breed.lowercased()). Plenty for the breed — make sure rest days happen."
            )
        } else {
            return DogInsight(
                id: "volume.on",
                kind: .volume,
                title: "On the breed mark",
                body: "\(breed) at \(dogName)'s stage do best around \(target) min daily. \(dogName)'s averaging \(avg) — about right."
            )
        }
    }

    // MARK: - Life stage

    private static func lifeStageInsight(
        for dog: Dog,
        walks: [Walk],
        now: Date,
        calendar: Calendar
    ) -> DogInsight? {
        let stage = lifeStage(for: dog, calendar: calendar)
        let dogName = dog.name

        switch stage {
        case .puppy:
            return DogInsight(
                id: "stage.puppy",
                kind: .lifeStage,
                title: "Puppy pacing",
                body: "Puppies do better with several short walks than one long one. Aim for 5 min per month of age, twice a day, while \(dogName)'s growing."
            )
        case .senior:
            // Are walks already split into multiple shorter sessions per day?
            // If so, reinforce the pattern. Otherwise, suggest the split.
            if averageWalksPerActiveDay(walks: walks, calendar: calendar) >= 1.7 {
                return DogInsight(
                    id: "stage.senior.matched",
                    kind: .lifeStage,
                    title: "Seniors thrive on this",
                    body: "Senior dogs do best with two or three shorter walks rather than one long one. \(dogName)'s split-walk pattern is well-matched to that."
                )
            }
            return DogInsight(
                id: "stage.senior.suggest",
                kind: .lifeStage,
                title: "Try splitting walks",
                body: "Senior joints fare better with two or three shorter walks per day than one long one. Worth trying with \(dogName)."
            )
        case .adult:
            return nil  // Adults don't need a generic life-stage card; volume + pattern do the talking.
        }
    }

    // MARK: - Health

    /// Health-flag-driven cautions. Each fires only when the relevant flag
    /// is set on the Dog — never spurious for a healthy dog.
    private static func healthInsights(for dog: Dog, walks: [Walk]) -> [DogInsight] {
        var out: [DogInsight] = []
        let dogName = dog.name

        if dog.hasArthritis || dog.hasHipDysplasia {
            out.append(
                DogInsight(
                    id: "health.joints",
                    kind: .health,
                    title: "Steady is kinder",
                    body: "With \(dogName)'s joint condition, steady-pace walks beat sudden sprints. Avoid back-to-back high-intensity days."
                )
            )
        }
        if dog.isBrachycephalic {
            out.append(
                DogInsight(
                    id: "health.brachy",
                    kind: .health,
                    title: "Watch the heat",
                    body: "Flat-faced breeds overheat fast. On warm afternoons, prefer mornings or evenings for \(dogName)'s walks."
                )
            )
        }
        return out
    }

    // MARK: - Time-of-day pattern

    private static func timeOfDayInsight(
        for dog: Dog,
        walks: [Walk],
        calendar: Calendar
    ) -> DogInsight? {
        guard walks.count >= 5 else { return nil }
        var buckets: [PartOfDay: Int] = [:]
        for walk in walks {
            buckets[partOfDay(for: walk.startedAt, calendar: calendar), default: 0] += 1
        }
        let total = walks.count
        guard let top = buckets.max(by: { $0.value < $1.value }) else { return nil }
        let share = Double(top.value) / Double(total)
        guard share >= 0.6 else { return nil }

        let dogName = dog.name
        return DogInsight(
            id: "tod.\(top.key.rawValue)",
            kind: .timeOfDay,
            title: "A creature of routine",
            body: "\(Int(round(share * 100)))% of \(dogName)'s walks happen in the \(top.key.label). The rhythm is settling in."
        )
    }

    // MARK: - Trend

    private static func trendInsight(
        for dog: Dog,
        walks: [Walk],
        now: Date,
        calendar: Calendar
    ) -> DogInsight? {
        let todayDay = calendar.startOfDay(for: now)
        let thisStart = calendar.date(byAdding: .day, value: -6, to: todayDay) ?? todayDay
        let lastStart = calendar.date(byAdding: .day, value: -13, to: todayDay) ?? todayDay
        let lastEnd = calendar.date(byAdding: .day, value: -7, to: todayDay) ?? todayDay

        let thisMinutes = walks.filter {
            let d = calendar.startOfDay(for: $0.startedAt)
            return d >= thisStart && d <= todayDay
        }.reduce(0) { $0 + $1.durationMinutes }
        let lastMinutes = walks.filter {
            let d = calendar.startOfDay(for: $0.startedAt)
            return d >= lastStart && d <= lastEnd
        }.reduce(0) { $0 + $1.durationMinutes }

        guard lastMinutes > 0 else { return nil }
        let delta = thisMinutes - lastMinutes
        guard abs(delta) >= 15 else { return nil }  // a small wobble isn't a trend

        if delta > 0 {
            return DogInsight(
                id: "trend.up",
                kind: .trend,
                title: "Building momentum",
                body: "\(thisMinutes) min this week, \(delta) more than last. The habit is locking in."
            )
        } else {
            return DogInsight(
                id: "trend.down",
                kind: .trend,
                title: "A quieter week",
                body: "\(thisMinutes) min this week, \(abs(delta)) less than last. Worth a longer walk before the weekend if you can."
            )
        }
    }

    // MARK: - Streak

    private static func streakInsight(
        for dog: Dog,
        now: Date,
        calendar: Calendar
    ) -> DogInsight? {
        let streak = StreakService.currentStreak(for: dog, today: now, calendar: calendar)
        guard streak >= 5 else { return nil }
        return DogInsight(
            id: "streak.long",
            kind: .streak,
            title: "Streak holding",
            body: "\(streak) consecutive days of meeting \(dog.name)'s target. That's the kind of consistency that compounds."
        )
    }

    // MARK: - Helpers

    /// 7-day rolling average of daily walking minutes (using the most recent
    /// 7 days that have any walks). Excluding zero-walk days here would over
    /// state the average, so we average across all days in the window.
    private static func recentDailyAverage(
        walks: [Walk],
        now: Date,
        calendar: Calendar
    ) -> Int {
        let todayDay = calendar.startOfDay(for: now)
        let windowStart = calendar.date(byAdding: .day, value: -6, to: todayDay) ?? todayDay
        let totalMinutes = walks.filter {
            let d = calendar.startOfDay(for: $0.startedAt)
            return d >= windowStart && d <= todayDay
        }.reduce(0) { $0 + $1.durationMinutes }
        return Int(round(Double(totalMinutes) / 7.0))
    }

    /// Mean walks per day on days that had at least one walk. Higher numbers
    /// signal a multi-walk-per-day pattern (relevant to senior advice).
    private static func averageWalksPerActiveDay(walks: [Walk], calendar: Calendar) -> Double {
        var byDay: [Date: Int] = [:]
        for walk in walks {
            byDay[calendar.startOfDay(for: walk.startedAt), default: 0] += 1
        }
        guard !byDay.isEmpty else { return 0 }
        let total = byDay.values.reduce(0, +)
        return Double(total) / Double(byDay.count)
    }

    private static func lifeStage(for dog: Dog, calendar: Calendar) -> LifeStage {
        let months = calendar.dateComponents([.month], from: dog.dateOfBirth, to: .now).month ?? 0
        if months < 12 { return .puppy }
        if months >= 12 * 8 { return .senior }
        return .adult
    }

    private enum LifeStage { case puppy, adult, senior }

    private enum PartOfDay: String, Hashable {
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
