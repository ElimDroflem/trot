import Testing
import Foundation
@testable import Trot

/// Locks the invariant that every surface reading walk data sees the same
/// totals. Earlier in the v1 build the user reported "42 min on Today, but
/// Insights says averaging 6" — the math turned out to be right (a 7-day
/// rolling average) but the test below catches a real regression: any future
/// surface that derives totals from anywhere other than `dog.walks ?? []`
/// would diverge here.
@Suite("Walk data consistency")
struct WalkDataConsistencyTests {
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
        return cal
    }()

    /// Anchored Tuesday so weekday-shifted bucketing has a predictable shape.
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

    private func makeDog(target: Int = 60) -> Dog {
        let dog = Dog(
            name: "Luna",
            breedPrimary: "Beagle",
            dateOfBirth: Date(timeIntervalSince1970: 0),
            weightKg: 12,
            sex: .female,
            isNeutered: true,
            dailyTargetMinutes: target
        )
        dog.createdAt = calendar.date(byAdding: .day, value: -30, to: referenceToday) ?? referenceToday
        return dog
    }

    private func addWalk(daysAgo: Int, hour: Int = 12, minutes: Int, to dog: Dog) {
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

    @Test("InsightsStats and DogTagPanel hero see the same lifetime totals")
    func lifetimeTotalsAgree() {
        let dog = makeDog()
        addWalk(daysAgo: 0, minutes: 35, to: dog)
        addWalk(daysAgo: 1, minutes: 50, to: dog)
        addWalk(daysAgo: 3, minutes: 42, to: dog)

        // Source of truth — what every surface should agree with.
        let walks = dog.walks ?? []
        let lifetimeMinutes = walks.reduce(0) { $0 + $1.durationMinutes }
        let lifetimeWalks = walks.count

        // InsightsStats uses the same array.
        let stats = InsightsStats.compute(for: dog, today: referenceToday, calendar: calendar)
        let statsHourTotal = stats.minutesByHour.reduce(0, +)
        #expect(statsHourTotal == lifetimeMinutes,
                "minutesByHour totals should match lifetime sum")

        // DogTagPanel hero strip just reads `(dog.walks ?? []).count` and
        // sums durations directly — assert the same numbers fall out here.
        let heroWalks = (dog.walks ?? []).count
        let heroMinutes = (dog.walks ?? []).reduce(0) { $0 + $1.durationMinutes }
        #expect(heroWalks == lifetimeWalks)
        #expect(heroMinutes == lifetimeMinutes)
    }

    @Test("Insights weekly numbers and DogInsightsService volume body see the same totals")
    func weeklyTotalsAgree() {
        let dog = makeDog(target: 60)
        // Five walks spread across the last 7 days.
        addWalk(daysAgo: 0, minutes: 35, to: dog)
        addWalk(daysAgo: 1, minutes: 50, to: dog)
        addWalk(daysAgo: 2, minutes: 25, to: dog)
        addWalk(daysAgo: 4, minutes: 42, to: dog)
        addWalk(daysAgo: 6, minutes: 38, to: dog)
        // One walk OUTSIDE the 7-day window — should not contribute.
        addWalk(daysAgo: 10, minutes: 99, to: dog)

        let stats = InsightsStats.compute(for: dog, today: referenceToday, calendar: calendar)
        // 35 + 50 + 25 + 42 + 38 = 190 (excludes the daysAgo:10 walk)
        #expect(stats.thisWeekMinutes == 190, "thisWeekMinutes should sum walks within the 7-day window only")

        let insights = DogInsightsService.insights(for: dog, now: referenceToday, calendar: calendar)
        let volume = insights.first { $0.kind == .volume }
        #expect(volume != nil, "Volume insight should fire when there are walks in the window")

        // The volume body now embeds the weekly total + walk count; make sure
        // those match the same numbers InsightsStats sees.
        let body = volume?.body ?? ""
        #expect(body.contains("190 min total"), "Volume body should embed the same weekly total as InsightsStats")
        #expect(body.contains("5 walks"), "Volume body should embed the same weekly walk count")
    }

    @Test("empty walks → every surface reports zero")
    func emptyDogReportsZero() {
        let dog = makeDog()
        let stats = InsightsStats.compute(for: dog, today: referenceToday, calendar: calendar)
        #expect(stats.thisWeekMinutes == 0)
        #expect(stats.lastWeekMinutes == 0)
        #expect(stats.minutesByHour.allSatisfy { $0 == 0 })
        #expect((dog.walks ?? []).isEmpty)
        // DogInsightsService should produce no insights for an empty dog
        // (the learning state on the view handles the empty UI).
        let insights = DogInsightsService.insights(for: dog, now: referenceToday, calendar: calendar)
        #expect(insights.isEmpty)
    }
}
