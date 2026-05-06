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

    // MARK: - Auto-show

    /// Build a Date at the given (year, month, day, hour) in the test calendar.
    private func dateAt(year: Int, month: Int, day: Int, hour: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = hour
        return calendar.date(from: c) ?? referenceToday
    }

    /// 2026-05-12 was a Tuesday. The most recent prior Sunday was 2026-05-10.
    @Test("currentWeekKey returns the most recent Sunday at startOfDay")
    func weekKeyFromMidweek() {
        let tuesday = dateAt(year: 2026, month: 5, day: 12, hour: 14)
        let key = RecapService.currentWeekKey(today: tuesday, calendar: calendar)
        let expected = calendar.startOfDay(for: dateAt(year: 2026, month: 5, day: 10, hour: 0))
        #expect(key == expected)
    }

    @Test("currentWeekKey on Sunday returns that Sunday's startOfDay")
    func weekKeyOnSunday() {
        let sunday = dateAt(year: 2026, month: 5, day: 10, hour: 14)
        let key = RecapService.currentWeekKey(today: sunday, calendar: calendar)
        #expect(key == calendar.startOfDay(for: sunday))
    }

    /// Folded matrix per `feedback_targeted_tests_during_iteration.md`:
    /// "Use @Test(arguments:) for boundary tables." The four shouldAutoShow
    /// branches in one parameterised test instead of four separate ones.
    /// Args: (year, month, day, hour, expected)
    @Test(arguments: [
        // 2026-05-10 is Sunday; 2026-05-09 is Saturday.
        (2026, 5, 10, 20, true),   // Sunday 20:00, unseen → show
        (2026, 5, 10, 19, true),   // Sunday 19:00 boundary → show
        (2026, 5, 10, 18, false),  // Sunday 18:00 → too early
        (2026, 5, 9, 20, false),   // Saturday 20:00 → wrong day
        (2026, 5, 12, 20, false),  // Tuesday 20:00 → wrong day
    ])
    func shouldAutoShowMatrix(year: Int, month: Int, day: Int, hour: Int, expected: Bool) {
        let dog = makeDog()
        let now = dateAt(year: year, month: month, day: day, hour: hour)
        #expect(RecapService.shouldAutoShow(for: dog, today: now, calendar: calendar) == expected)
    }

    @Test("shouldAutoShow returns false when this week has been seen")
    func shouldAutoShowSuppressedAfterSeen() {
        let dog = makeDog()
        let sundayEvening = dateAt(year: 2026, month: 5, day: 10, hour: 20)
        // First check: should show
        #expect(RecapService.shouldAutoShow(for: dog, today: sundayEvening, calendar: calendar) == true)
        // Mark seen → second check should not re-show
        RecapService.markSeen(for: dog, today: sundayEvening, calendar: calendar)
        #expect(RecapService.shouldAutoShow(for: dog, today: sundayEvening, calendar: calendar) == false)
    }

    @Test("markSeen for last week does NOT suppress this week")
    func markSeenIsPerWeek() {
        let dog = makeDog()
        let lastSunday = dateAt(year: 2026, month: 5, day: 3, hour: 20)
        let thisSunday = dateAt(year: 2026, month: 5, day: 10, hour: 20)
        RecapService.markSeen(for: dog, today: lastSunday, calendar: calendar)
        #expect(RecapService.shouldAutoShow(for: dog, today: thisSunday, calendar: calendar) == true,
                "a new week should re-trigger the auto-show")
    }
}
