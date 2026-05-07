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

    @Test("empty dog → all zeros, no streak, no longest, no average")
    func emptyDog() {
        let dog = makeDog()
        let stats = InsightsStats.compute(for: dog, today: referenceToday, calendar: calendar)
        #expect(stats.thisWeekMinutes == 0)
        #expect(stats.lastWeekMinutes == 0)
        #expect(stats.longestWalkMinutes == 0)
        #expect(stats.currentStreak == 0)
        #expect(stats.minutesByWeekday == [0, 0, 0, 0, 0, 0, 0])
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

    @Test("weekday histogram is Mon-first")
    func weekdayHistogramMonFirst() {
        let dog = makeDog()
        // 2026-05-12 is a Tuesday (raw weekday 3).
        // daysAgo: 0 → Tuesday → index 1 in Mon-first array
        // daysAgo: 1 → Monday  → index 0
        // daysAgo: 6 → Wednesday → index 2 (since today is Tue, 6 days ago is last Wednesday)
        addWalk(daysAgo: 0, minutes: 10, to: dog)
        addWalk(daysAgo: 1, minutes: 20, to: dog)
        addWalk(daysAgo: 6, minutes: 30, to: dog)

        let stats = InsightsStats.compute(for: dog, today: referenceToday, calendar: calendar)
        #expect(stats.minutesByWeekday[0] == 20, "Monday total")
        #expect(stats.minutesByWeekday[1] == 10, "Tuesday total")
        #expect(stats.minutesByWeekday[2] == 30, "Wednesday total")
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
