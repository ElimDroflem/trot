import Testing
import Foundation
@testable import Trot

@Suite("RecapService")
struct RecapServiceTests {
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
        return cal
    }()

    private let referenceToday: Date = {
        var components = DateComponents()
        components.year = 2026; components.month = 5; components.day = 12
        components.hour = 14
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
        return cal.date(from: components) ?? .now
    }()

    private func makeDog(targetMinutes: Int = 60, createdDaysAgo: Int = 30) -> Dog {
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

    @discardableResult
    private func addWalk(daysAgo: Int, minutes: Int = 30, hour: Int = 9, to dog: Dog) -> Walk {
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

    // MARK: - Window splits

    @Test("walk today counts in this-week, not last-week")
    func walkTodayCountsThisWeek() {
        let dog = makeDog()
        addWalk(daysAgo: 0, minutes: 30, to: dog)
        let recap = RecapService.weekly(for: dog, today: referenceToday, calendar: calendar)
        #expect(recap.thisWeek.totalMinutes == 30)
        #expect(recap.lastWeek.totalMinutes == 0)
    }

    @Test("walk 6 days ago is the trailing edge of this-week")
    func walkSixDaysAgoIsThisWeek() {
        let dog = makeDog()
        addWalk(daysAgo: 6, minutes: 30, to: dog)
        let recap = RecapService.weekly(for: dog, today: referenceToday, calendar: calendar)
        #expect(recap.thisWeek.totalMinutes == 30)
        #expect(recap.lastWeek.totalMinutes == 0)
    }

    @Test("walk 7 days ago crosses the boundary into last-week")
    func walkSevenDaysAgoIsLastWeek() {
        let dog = makeDog()
        addWalk(daysAgo: 7, minutes: 30, to: dog)
        let recap = RecapService.weekly(for: dog, today: referenceToday, calendar: calendar)
        #expect(recap.thisWeek.totalMinutes == 0)
        #expect(recap.lastWeek.totalMinutes == 30)
    }

    @Test("walk 13 days ago is the trailing edge of last-week")
    func walkThirteenDaysAgoIsLastWeek() {
        let dog = makeDog()
        addWalk(daysAgo: 13, minutes: 30, to: dog)
        let recap = RecapService.weekly(for: dog, today: referenceToday, calendar: calendar)
        #expect(recap.lastWeek.totalMinutes == 30)
    }

    @Test("walk 14 days ago is outside both windows")
    func walkFourteenDaysAgoOutsideBoth() {
        let dog = makeDog()
        addWalk(daysAgo: 14, minutes: 30, to: dog)
        let recap = RecapService.weekly(for: dog, today: referenceToday, calendar: calendar)
        #expect(recap.thisWeek.totalMinutes == 0)
        #expect(recap.lastWeek.totalMinutes == 0)
    }

    // MARK: - Percent needs met

    @Test("seven hit days → 100% needs met")
    func percentNeedsMetFull() {
        let dog = makeDog(targetMinutes: 60)
        for offset in 0...6 {
            addWalk(daysAgo: offset, minutes: 60, to: dog)
        }
        let recap = RecapService.weekly(for: dog, today: referenceToday, calendar: calendar)
        #expect(recap.thisWeek.percentNeedsMet == 1.0)
    }

    @Test("over-target days are capped at 100% per day")
    func percentCapsAtHundred() {
        let dog = makeDog(targetMinutes: 60)
        for offset in 0...6 {
            // 200% of target each day — should still cap at 1.0 average
            addWalk(daysAgo: offset, minutes: 120, to: dog)
        }
        let recap = RecapService.weekly(for: dog, today: referenceToday, calendar: calendar)
        #expect(recap.thisWeek.percentNeedsMet == 1.0, "going over target does not score higher")
    }

    @Test("half-target each day → 50%")
    func percentHalf() {
        let dog = makeDog(targetMinutes: 60)
        for offset in 0...6 {
            addWalk(daysAgo: offset, minutes: 30, to: dog)
        }
        let recap = RecapService.weekly(for: dog, today: referenceToday, calendar: calendar)
        #expect(abs(recap.thisWeek.percentNeedsMet - 0.5) < 0.01)
    }

    @Test("zero walks → 0%")
    func percentZero() {
        let dog = makeDog(targetMinutes: 60)
        let recap = RecapService.weekly(for: dog, today: referenceToday, calendar: calendar)
        #expect(recap.thisWeek.percentNeedsMet == 0)
        #expect(recap.thisWeek.totalMinutes == 0)
        #expect(recap.thisWeek.walkCount == 0)
    }

    // MARK: - Comparison

    @Test("delta is positive when this-week beats last-week")
    func deltaPositive() {
        let dog = makeDog()
        addWalk(daysAgo: 0, minutes: 60, to: dog)
        addWalk(daysAgo: 7, minutes: 40, to: dog)
        let recap = RecapService.weekly(for: dog, today: referenceToday, calendar: calendar)
        #expect(recap.minutesDelta == 20)
        #expect(recap.hasComparison == true)
    }

    @Test("delta is negative when this-week is below last-week")
    func deltaNegative() {
        let dog = makeDog()
        addWalk(daysAgo: 0, minutes: 30, to: dog)
        addWalk(daysAgo: 7, minutes: 60, to: dog)
        let recap = RecapService.weekly(for: dog, today: referenceToday, calendar: calendar)
        #expect(recap.minutesDelta == -30)
    }

    @Test("brand-new user with no last-week data: hasComparison = false")
    func noComparisonForNewUser() {
        let dog = makeDog(createdDaysAgo: 0)
        addWalk(daysAgo: 0, minutes: 30, to: dog)
        let recap = RecapService.weekly(for: dog, today: referenceToday, calendar: calendar)
        #expect(recap.hasComparison == false)
    }

    // MARK: - Featured insight

    @Test("featured insight prefers part-of-day pattern over lifetime")
    func featuredPrefersPartOfDay() {
        let dog = makeDog()
        // 3 morning walks → triggers part-of-day insight
        addWalk(daysAgo: 0, hour: 8, to: dog)
        addWalk(daysAgo: 1, hour: 9, to: dog)
        addWalk(daysAgo: 2, hour: 7, to: dog)
        let recap = RecapService.weekly(for: dog, today: referenceToday, calendar: calendar)
        #expect(recap.featuredInsight?.title == "When you walk")
    }

    @Test("featured insight falls back to lifetime when no pattern")
    func featuredFallsBackToLifetime() {
        let dog = makeDog()
        addWalk(daysAgo: 0, minutes: 30, to: dog)
        let recap = RecapService.weekly(for: dog, today: referenceToday, calendar: calendar)
        #expect(recap.featuredInsight?.title == "Lifetime walks")
    }

    @Test("dog name and photo are wired through")
    func metadataPassthrough() {
        let dog = makeDog()
        dog.name = "Bruno"
        dog.photo = Data([0x01, 0x02, 0x03])
        let recap = RecapService.weekly(for: dog, today: referenceToday, calendar: calendar)
        #expect(recap.dogName == "Bruno")
        #expect(recap.photo == Data([0x01, 0x02, 0x03]))
    }
}
