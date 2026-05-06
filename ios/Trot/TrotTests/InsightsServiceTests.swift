import Testing
import Foundation
@testable import Trot

@Suite("InsightsService")
struct InsightsServiceTests {
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
        return cal
    }()

    private let referenceToday: Date = {
        var components = DateComponents()
        components.year = 2026; components.month = 5; components.day = 12
        components.hour = 12
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
        return cal.date(from: components) ?? .now
    }()

    private func makeDog(targetMinutes: Int = 60, createdDaysAgo: Int = 0) -> Dog {
        let dog = Dog(
            name: "Test",
            breedPrimary: "Mixed",
            dateOfBirth: Date(timeIntervalSince1970: 0),
            weightKg: 10,
            sex: .female,
            isNeutered: true,
            dailyTargetMinutes: targetMinutes
        )
        dog.createdAt = calendar.date(byAdding: .day, value: -createdDaysAgo, to: referenceToday) ?? referenceToday
        return dog
    }

    /// Adds a walk N days ago at the given hour-of-day (24h). Hour controls part-of-day bucketing.
    @discardableResult
    private func addWalk(daysAgo: Int, hour: Int = 9, minutes: Int = 30, to dog: Dog) -> Walk {
        let dayBase = calendar.date(byAdding: .day, value: -daysAgo, to: referenceToday) ?? referenceToday
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: dayBase) ?? dayBase
        let walk = Walk(
            startedAt: date,
            durationMinutes: minutes,
            distanceMeters: nil,
            source: .manual,
            notes: "",
            dogs: [dog]
        )
        dog.walks = (dog.walks ?? []) + [walk]
        return walk
    }

    // MARK: - Learning progress

    @Test("brand-new dog: day 1 of 7, no observations")
    func dayOne() {
        let dog = makeDog(createdDaysAgo: 0)
        let state = InsightsService.state(for: dog, today: referenceToday, calendar: calendar)
        #expect(state.learning?.daysOfData == 1)
        #expect(state.learning?.target == 7)
        #expect(state.observations.isEmpty)
    }

    @Test("day 4 of 7, fraction is around 0.57")
    func dayFour() {
        let dog = makeDog(createdDaysAgo: 3)
        let state = InsightsService.state(for: dog, today: referenceToday, calendar: calendar)
        #expect(state.learning?.daysOfData == 4)
        #expect(state.learning?.fraction ?? 0 > 0.5)
        #expect(state.learning?.fraction ?? 0 < 0.6)
    }

    @Test("day 7+: learning is gone")
    func dayEightLearningCleared() {
        let dog = makeDog(createdDaysAgo: 7)
        let state = InsightsService.state(for: dog, today: referenceToday, calendar: calendar)
        #expect(state.learning == nil)
    }

    // MARK: - Lifetime summary observation

    @Test("single walk fires the lifetime-walks observation in singular form")
    func singleWalkLifetime() {
        let dog = makeDog(createdDaysAgo: 0)
        addWalk(daysAgo: 0, minutes: 32, to: dog)
        let state = InsightsService.state(for: dog, today: referenceToday, calendar: calendar)
        let lifetime = state.observations.first { $0.title == "Lifetime walks" }
        #expect(lifetime?.body == "1 walk logged, 32 minutes.")
    }

    @Test("multiple walks fire the lifetime-walks observation in plural form")
    func multipleWalksLifetime() {
        let dog = makeDog(createdDaysAgo: 2)
        addWalk(daysAgo: 0, minutes: 30, to: dog)
        addWalk(daysAgo: 1, minutes: 25, to: dog)
        let state = InsightsService.state(for: dog, today: referenceToday, calendar: calendar)
        let lifetime = state.observations.first { $0.title == "Lifetime walks" }
        #expect(lifetime?.body == "2 walks logged, 55 minutes total.")
    }

    // MARK: - Part-of-day observation

    @Test("part-of-day observation needs at least 3 walks")
    func partOfDayNeedsThree() {
        let dog = makeDog(createdDaysAgo: 2)
        addWalk(daysAgo: 0, hour: 8, to: dog)
        addWalk(daysAgo: 1, hour: 8, to: dog)
        let state = InsightsService.state(for: dog, today: referenceToday, calendar: calendar)
        let partOfDay = state.observations.first { $0.title == "When you walk" }
        #expect(partOfDay == nil)
    }

    @Test("3+ morning walks → morning dominates")
    func morningDominates() {
        let dog = makeDog(createdDaysAgo: 5)
        addWalk(daysAgo: 0, hour: 8, to: dog)
        addWalk(daysAgo: 1, hour: 9, to: dog)
        addWalk(daysAgo: 2, hour: 7, to: dog)
        let state = InsightsService.state(for: dog, today: referenceToday, calendar: calendar)
        let partOfDay = state.observations.first { $0.title == "When you walk" }
        #expect(partOfDay?.body.contains("morning") == true)
    }

    @Test("evenly split times do not produce a part-of-day observation")
    func evenlySplitNoDominance() {
        let dog = makeDog(createdDaysAgo: 5)
        addWalk(daysAgo: 0, hour: 8, to: dog)   // morning
        addWalk(daysAgo: 1, hour: 14, to: dog)  // afternoon
        addWalk(daysAgo: 2, hour: 19, to: dog)  // evening
        let state = InsightsService.state(for: dog, today: referenceToday, calendar: calendar)
        let partOfDay = state.observations.first { $0.title == "When you walk" }
        #expect(partOfDay == nil, "33/33/33 — no bucket clears 50%")
    }

    // MARK: - Empty state

    @Test("no walks: empty observations list")
    func noWalksNoObservations() {
        let dog = makeDog(createdDaysAgo: 3)
        let state = InsightsService.state(for: dog, today: referenceToday, calendar: calendar)
        #expect(state.observations.isEmpty)
        #expect(state.learning != nil, "still in learning state regardless")
    }

    // MARK: - Weekly trend

    @Test("weekly trend: needs ≥7 days of data")
    func weeklyTrendNotBeforeWeekOne() {
        let dog = makeDog(createdDaysAgo: 5)
        for offset in 0...4 {
            addWalk(daysAgo: offset, minutes: 30, to: dog)
        }
        let state = InsightsService.state(for: dog, today: referenceToday, calendar: calendar)
        #expect(state.observations.first(where: { $0.title == "Weekly trend" }) == nil)
    }

    @Test("weekly trend: needs last week to have walks too")
    func weeklyTrendSkipsWhenLastWeekEmpty() {
        let dog = makeDog(createdDaysAgo: 8)
        // Only this-week walks
        for offset in 0...3 {
            addWalk(daysAgo: offset, minutes: 30, to: dog)
        }
        let state = InsightsService.state(for: dog, today: referenceToday, calendar: calendar)
        #expect(state.observations.first(where: { $0.title == "Weekly trend" }) == nil)
    }

    @Test("weekly trend: positive delta uses 'more than last' phrasing")
    func weeklyTrendUp() {
        let dog = makeDog(createdDaysAgo: 14)
        addWalk(daysAgo: 0, minutes: 60, to: dog)
        addWalk(daysAgo: 1, minutes: 60, to: dog)
        addWalk(daysAgo: 7, minutes: 30, to: dog)
        let state = InsightsService.state(for: dog, today: referenceToday, calendar: calendar)
        let trend = state.observations.first { $0.title == "Weekly trend" }
        #expect(trend?.body.contains("more than last") == true)
    }

    @Test("weekly trend: negative delta uses 'fewer than last' phrasing")
    func weeklyTrendDown() {
        let dog = makeDog(createdDaysAgo: 14)
        addWalk(daysAgo: 0, minutes: 30, to: dog)
        addWalk(daysAgo: 7, minutes: 60, to: dog)
        addWalk(daysAgo: 8, minutes: 60, to: dog)
        let state = InsightsService.state(for: dog, today: referenceToday, calendar: calendar)
        let trend = state.observations.first { $0.title == "Weekly trend" }
        #expect(trend?.body.contains("fewer than last") == true)
    }

    // MARK: - Weekday/weekend split

    /// 2026-05-12 is Tuesday. So daysAgo=4 is Friday, 5=Thurs, 6=Wed, 7=Tues.
    /// Saturday is daysAgo=3, Sunday is daysAgo=2.
    @Test("weekday/weekend split: needs ≥14 days of data")
    func splitNotBeforeTwoWeeks() {
        let dog = makeDog(createdDaysAgo: 10)
        addWalk(daysAgo: 2, minutes: 60, to: dog)  // Sunday
        addWalk(daysAgo: 3, minutes: 60, to: dog)  // Saturday
        let state = InsightsService.state(for: dog, today: referenceToday, calendar: calendar)
        #expect(state.observations.first(where: { $0.title == "Weekday vs weekend" }) == nil)
    }

    @Test("weekday/weekend split: surfaces when weekend per-day clearly higher")
    func splitWeekendDominant() {
        let dog = makeDog(createdDaysAgo: 14)
        addWalk(daysAgo: 2, minutes: 90, to: dog)  // Sunday
        addWalk(daysAgo: 3, minutes: 90, to: dog)  // Saturday
        addWalk(daysAgo: 7, minutes: 30, to: dog)  // Tuesday (weekday)
        let state = InsightsService.state(for: dog, today: referenceToday, calendar: calendar)
        let split = state.observations.first { $0.title == "Weekday vs weekend" }
        #expect(split != nil)
        #expect(split?.body.contains("weekend") == true)
    }

    @Test("weekday/weekend split: skipped when split is too even")
    func splitEvenSkipped() {
        let dog = makeDog(createdDaysAgo: 14)
        // 5 weekdays × 30 = 150 → 30/day; 2 weekend × 30 = 60 → 30/day. Equal.
        addWalk(daysAgo: 2, minutes: 30, to: dog)
        addWalk(daysAgo: 3, minutes: 30, to: dog)
        addWalk(daysAgo: 4, minutes: 30, to: dog)
        addWalk(daysAgo: 5, minutes: 30, to: dog)
        addWalk(daysAgo: 6, minutes: 30, to: dog)
        addWalk(daysAgo: 7, minutes: 30, to: dog)
        addWalk(daysAgo: 8, minutes: 30, to: dog)
        let state = InsightsService.state(for: dog, today: referenceToday, calendar: calendar)
        #expect(state.observations.first(where: { $0.title == "Weekday vs weekend" }) == nil)
    }

    // MARK: - Favorite hour

    @Test("favorite hour: needs ≥7 walks")
    func favoriteHourNeedsSeven() {
        let dog = makeDog(createdDaysAgo: 14)
        for offset in 0...5 {
            addWalk(daysAgo: offset, hour: 8, to: dog)
        }
        let state = InsightsService.state(for: dog, today: referenceToday, calendar: calendar)
        #expect(state.observations.first(where: { $0.title == "Favorite hour" }) == nil)
    }

    @Test("favorite hour: ≥40% concentration surfaces it")
    func favoriteHourConcentrated() {
        let dog = makeDog(createdDaysAgo: 14)
        // 7 walks all at 8am → 100% at 8am
        for offset in 0...6 {
            addWalk(daysAgo: offset, hour: 8, to: dog)
        }
        let state = InsightsService.state(for: dog, today: referenceToday, calendar: calendar)
        let fav = state.observations.first { $0.title == "Favorite hour" }
        #expect(fav?.body.contains("8am") == true)
    }

    @Test("favorite hour: spread across hours, no surface")
    func favoriteHourSpread() {
        let dog = makeDog(createdDaysAgo: 14)
        // 7 walks across 7 different hours → top is 1/7 = ~14%, below 40% threshold
        for (offset, hour) in [(0, 7), (1, 9), (2, 12), (3, 14), (4, 17), (5, 19), (6, 21)] {
            addWalk(daysAgo: offset, hour: hour, to: dog)
        }
        let state = InsightsService.state(for: dog, today: referenceToday, calendar: calendar)
        #expect(state.observations.first(where: { $0.title == "Favorite hour" }) == nil)
    }
}
