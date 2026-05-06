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
}
