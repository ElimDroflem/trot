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
            calendar: calendar
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
        calendar: Calendar
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
        // "Mornings seem to be her thing" needs more than one or two morning walks to mean anything.
        if let dominant = dominantPartOfDay(walks: walks, calendar: calendar) {
            insights.append(
                Insight(
                    title: "When you walk",
                    body: "Most walks happen in the \(dominant.label). \(dominant.share)% so far."
                )
            )
        }

        return insights
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
