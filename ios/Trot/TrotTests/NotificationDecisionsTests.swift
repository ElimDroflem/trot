import Testing
import Foundation
@testable import Trot

@Suite("NotificationDecisions")
struct NotificationDecisionsTests {
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
        return cal
    }()

    private func date(year: Int, month: Int, day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? .now
    }

    // MARK: - Nudge

    @Test("nudge: Sunday suppression returns nil")
    func nudgeSundaySuppression() {
        // 2026-05-10 is a Sunday
        let sunday = date(year: 2026, month: 5, day: 10, hour: 14)
        let result = NotificationDecisions.nudgeTime(
            minutesToday: 0, targetMinutes: 60, now: sunday, calendar: calendar
        )
        #expect(result == nil)
    }

    @Test("nudge: after 19:00 returns nil")
    func nudgeAfterNineteen() {
        let monday = date(year: 2026, month: 5, day: 11, hour: 20)
        let result = NotificationDecisions.nudgeTime(
            minutesToday: 0, targetMinutes: 60, now: monday, calendar: calendar
        )
        #expect(result == nil)
    }

    @Test("nudge: target hit returns nil")
    func nudgeTargetHit() {
        let monday = date(year: 2026, month: 5, day: 11, hour: 14)
        let result = NotificationDecisions.nudgeTime(
            minutesToday: 30, targetMinutes: 60, now: monday, calendar: calendar
        )
        #expect(result == nil, "30 minutes is exactly 50% of 60, qualifies as hit")
    }

    @Test("nudge: under target before 19:00 on weekday returns 19:00 today")
    func nudgeFiresWhenAppropriate() {
        let monday = date(year: 2026, month: 5, day: 11, hour: 10)
        let result = NotificationDecisions.nudgeTime(
            minutesToday: 5, targetMinutes: 60, now: monday, calendar: calendar
        )
        let expected = date(year: 2026, month: 5, day: 11, hour: 19)
        #expect(result == expected)
    }

    @Test("nudge: zero target is defensive nil")
    func nudgeZeroTargetSafe() {
        let monday = date(year: 2026, month: 5, day: 11, hour: 10)
        let result = NotificationDecisions.nudgeTime(
            minutesToday: 0, targetMinutes: 0, now: monday, calendar: calendar
        )
        #expect(result == nil)
    }

    // MARK: - Milestone

    @Test("milestone: streak of 7 returns tomorrow 9am")
    func milestoneSeven() {
        let now = date(year: 2026, month: 5, day: 11, hour: 14)
        let result = NotificationDecisions.milestoneFireTime(currentStreak: 7, now: now, calendar: calendar)
        let expected = date(year: 2026, month: 5, day: 12, hour: 9)
        #expect(result?.count == 7)
        #expect(result?.fireAt == expected)
    }

    @Test("milestone: 14 and 30 also qualify")
    func milestoneFourteenAndThirty() {
        let now = date(year: 2026, month: 5, day: 11, hour: 14)
        #expect(NotificationDecisions.milestoneFireTime(currentStreak: 14, now: now, calendar: calendar)?.count == 14)
        #expect(NotificationDecisions.milestoneFireTime(currentStreak: 30, now: now, calendar: calendar)?.count == 30)
    }

    @Test("milestone: non-milestone counts return nil")
    func milestoneNonMilestoneNil() {
        let now = date(year: 2026, month: 5, day: 11, hour: 14)
        #expect(NotificationDecisions.milestoneFireTime(currentStreak: 6, now: now, calendar: calendar) == nil)
        #expect(NotificationDecisions.milestoneFireTime(currentStreak: 8, now: now, calendar: calendar) == nil)
        #expect(NotificationDecisions.milestoneFireTime(currentStreak: 31, now: now, calendar: calendar) == nil)
    }

    // MARK: - Recap

    @Test("recap: Monday returns next Sunday 19:00")
    func recapFromMonday() {
        let monday = date(year: 2026, month: 5, day: 11, hour: 10)
        let result = NotificationDecisions.nextRecapTime(now: monday, calendar: calendar)
        let expected = date(year: 2026, month: 5, day: 17, hour: 19)
        #expect(result == expected)
    }

    @Test("recap: Saturday returns tomorrow Sunday 19:00")
    func recapFromSaturday() {
        let saturday = date(year: 2026, month: 5, day: 16, hour: 14)
        let result = NotificationDecisions.nextRecapTime(now: saturday, calendar: calendar)
        let expected = date(year: 2026, month: 5, day: 17, hour: 19)
        #expect(result == expected)
    }

    @Test("recap: Sunday before 19:00 returns today 19:00")
    func recapFromSundayBefore() {
        let sundayBefore = date(year: 2026, month: 5, day: 17, hour: 14)
        let result = NotificationDecisions.nextRecapTime(now: sundayBefore, calendar: calendar)
        let expected = date(year: 2026, month: 5, day: 17, hour: 19)
        #expect(result == expected)
    }

    @Test("recap: Sunday after 19:00 returns next Sunday")
    func recapFromSundayAfter() {
        let sundayAfter = date(year: 2026, month: 5, day: 17, hour: 20)
        let result = NotificationDecisions.nextRecapTime(now: sundayAfter, calendar: calendar)
        let expected = date(year: 2026, month: 5, day: 24, hour: 19)
        #expect(result == expected)
    }
}
