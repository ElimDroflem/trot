import Testing
import Foundation
@testable import Trot

@Suite("InsightsStats")
struct InsightsStatsTests {
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
        return cal
    }()

    /// 2026-05-12 is a Tuesday. Convenient anchor for "this week" / "last week".
    private let referenceToday: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 12
        components.hour = 12
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
        return cal.date(from: components) ?? .now
    }()

    private func makeDog(targetMinutes: Int = 60) -> Dog {
        let dog = Dog(
            name: "Test",
            breedPrimary: "Mixed",
            dateOfBirth: Date(timeIntervalSince1970: 0),
            weightKg: 10,
            sex: .female,
            isNeutered: true,
            dailyTargetMinutes: targetMinutes
        )
        dog.createdAt = calendar.date(byAdding: .day, value: -30, to: referenceToday) ?? referenceToday
        return dog
    }

    private func addWalk(daysAgo: Int, minutes: Int, to dog: Dog) {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: referenceToday) ?? referenceToday
        let walk = Walk(
            startedAt: day,
            durationMinutes: minutes,
            distanceMeters: nil,
            source: .manual,
            notes: "",
            dogs: [dog]
        )
        dog.walks = (dog.walks ?? []) + [walk]
    }

    /// Helper that pins the wall-clock hour, so we can test the hour-of-day
    /// histogram without it being skewed by the noon-anchored `referenceToday`.
    private func addWalk(daysAgo: Int, hour: Int, minutes: Int, to dog: Dog) {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: referenceToday) ?? referenceToday
        let dayStart = calendar.startOfDay(for: day)
        let anchored = calendar.date(byAdding: .hour, value: hour, to: dayStart) ?? day
        let walk = Walk(
            startedAt: anchored,
            durationMinutes: minutes,
            distanceMeters: nil,
            source: .manual,
            notes: "",
            dogs: [dog]
        )
        dog.walks = (dog.walks ?? []) + [walk]
    }

    @Test("empty dog → all zeros, no streak, no longest, no average")
    func emptyDog() {
        let dog = makeDog()
        let stats = InsightsStats.compute(for: dog, today: referenceToday, calendar: calendar)
        #expect(stats.thisWeekMinutes == 0)
        #expect(stats.lastWeekMinutes == 0)
        #expect(stats.longestWalkMinutes == 0)
        #expect(stats.currentStreak == 0)
        #expect(stats.minutesByHour.count == 24)
        #expect(stats.minutesByHour.allSatisfy { $0 == 0 })
        #expect(stats.averageMinutesPerActiveDay == 0)
    }

    @Test("this week / last week split correctly across the 14-day window")
    func weekSplit() {
        let dog = makeDog()
        // Today (in this-week) — 30 min
        addWalk(daysAgo: 0, minutes: 30, to: dog)
        // Yesterday (this-week) — 20 min
        addWalk(daysAgo: 1, minutes: 20, to: dog)
        // 7 days ago (last-week) — 40 min
        addWalk(daysAgo: 7, minutes: 40, to: dog)
        // 13 days ago (last-week, edge) — 10 min
        addWalk(daysAgo: 13, minutes: 10, to: dog)
        // 14 days ago — outside both windows
        addWalk(daysAgo: 14, minutes: 99, to: dog)

        let stats = InsightsStats.compute(for: dog, today: referenceToday, calendar: calendar)
        #expect(stats.thisWeekMinutes == 50)
        #expect(stats.lastWeekMinutes == 50)
        #expect(stats.weekDelta == 0)
    }

    @Test("longest walk picks the single highest-minute walk")
    func longestWalk() {
        let dog = makeDog()
        addWalk(daysAgo: 0, minutes: 12, to: dog)
        addWalk(daysAgo: 1, minutes: 47, to: dog)
        addWalk(daysAgo: 2, minutes: 22, to: dog)
        let stats = InsightsStats.compute(for: dog, today: referenceToday, calendar: calendar)
        #expect(stats.longestWalkMinutes == 47)
    }

    @Test("hour-of-day histogram buckets walks by start hour")
    func hourOfDayHistogram() {
        let dog = makeDog()
        // Two walks starting at 7am on different days → 7am bucket = 25.
        addWalk(daysAgo: 0, hour: 7, minutes: 15, to: dog)
        addWalk(daysAgo: 1, hour: 7, minutes: 10, to: dog)
        // One walk starting at 6pm → 18:00 bucket = 40.
        addWalk(daysAgo: 2, hour: 18, minutes: 40, to: dog)
        // One walk starting at 9am → 9:00 bucket = 30.
        addWalk(daysAgo: 3, hour: 9, minutes: 30, to: dog)

        let stats = InsightsStats.compute(for: dog, today: referenceToday, calendar: calendar)
        #expect(stats.minutesByHour.count == 24)
        #expect(stats.minutesByHour[7] == 25, "7am bucket")
        #expect(stats.minutesByHour[9] == 30, "9am bucket")
        #expect(stats.minutesByHour[18] == 40, "6pm bucket")
        // Sanity: nothing leaks into adjacent buckets.
        #expect(stats.minutesByHour[6] == 0)
        #expect(stats.minutesByHour[8] == 0)
        #expect(stats.minutesByHour[17] == 0)
    }

    @Test("average per active day uses unique days, not lifetime walks")
    func averageActiveDays() {
        let dog = makeDog()
        // Two walks on same day (60 + 30) = 90 on one active day.
        // Two walks on a different day (10 + 20) = 30 on a second active day.
        // Lifetime: 4 walks, 120 min, 2 active days → 60 min/active day.
        addWalk(daysAgo: 0, minutes: 60, to: dog)
        addWalk(daysAgo: 0, minutes: 30, to: dog)
        addWalk(daysAgo: 3, minutes: 10, to: dog)
        addWalk(daysAgo: 3, minutes: 20, to: dog)
        let stats = InsightsStats.compute(for: dog, today: referenceToday, calendar: calendar)
        #expect(stats.averageMinutesPerActiveDay == 60)
    }

    @Test("week-delta display: zero last week shows '+N', no walks shows em dash")
    func weekDeltaDisplay() {
        let blank = makeDog()
        let blankStats = InsightsStats.compute(for: blank, today: referenceToday, calendar: calendar)
        #expect(blankStats.weekDeltaValue == "—")

        let onlyThisWeek = makeDog()
        addWalk(daysAgo: 0, minutes: 30, to: onlyThisWeek)
        let firstStats = InsightsStats.compute(for: onlyThisWeek, today: referenceToday, calendar: calendar)
        #expect(firstStats.weekDeltaValue == "+30")

        let down = makeDog()
        addWalk(daysAgo: 0, minutes: 10, to: down)   // this week: 10
        addWalk(daysAgo: 7, minutes: 30, to: down)   // last week: 30
        let downStats = InsightsStats.compute(for: down, today: referenceToday, calendar: calendar)
        #expect(downStats.weekDeltaValue == "-20")
        #expect(!downStats.weekDeltaIsBetter)
    }
}
