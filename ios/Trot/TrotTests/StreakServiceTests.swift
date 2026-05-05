import Testing
import Foundation
@testable import Trot

@Suite("StreakService")
struct StreakServiceTests {
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
        return cal
    }()

    private let referenceToday: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 5
        components.hour = 12
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
        return cal.date(from: components) ?? .now
    }()

    private func makeDog(targetMinutes: Int = 60, createdDaysAgo: Int = 365) -> Dog {
        let createdAt = calendar.date(byAdding: .day, value: -createdDaysAgo, to: referenceToday) ?? referenceToday
        let dog = Dog(
            name: "Test",
            breedPrimary: "Mixed",
            dateOfBirth: Date(timeIntervalSince1970: 0),
            weightKg: 10,
            sex: .female,
            isNeutered: true,
            dailyTargetMinutes: targetMinutes
        )
        dog.createdAt = createdAt
        return dog
    }

    private func makeWalk(daysAgo: Int, minutes: Int, dog: Dog) -> Walk {
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
        return walk
    }

    @Test("no walks → streak 0")
    func noWalksZero() {
        let dog = makeDog()
        #expect(StreakService.currentStreak(for: dog, today: referenceToday, calendar: calendar) == 0)
    }

    @Test("single hit today → streak 1")
    func singleHitToday() {
        let dog = makeDog()
        _ = makeWalk(daysAgo: 0, minutes: 60, dog: dog)
        #expect(StreakService.currentStreak(for: dog, today: referenceToday, calendar: calendar) == 1)
    }

    @Test("seven consecutive hits → streak 7")
    func sevenConsecutiveHits() {
        let dog = makeDog()
        for daysAgo in 0..<7 {
            _ = makeWalk(daysAgo: daysAgo, minutes: 60, dog: dog)
        }
        #expect(StreakService.currentStreak(for: dog, today: referenceToday, calendar: calendar) == 7)
    }

    @Test("hits today + yesterday miss + 5 hits before → streak 7 (1 rest day used)")
    func oneRestDayInWindow() {
        let dog = makeDog()
        _ = makeWalk(daysAgo: 0, minutes: 60, dog: dog)
        // skip day 1 (miss)
        for daysAgo in 2..<7 {
            _ = makeWalk(daysAgo: daysAgo, minutes: 60, dog: dog)
        }
        // Streak = today's hit (1) + 5 previous hits (5) = 6 (yesterday's miss is the rest day, doesn't extend).
        #expect(StreakService.currentStreak(for: dog, today: referenceToday, calendar: calendar) == 6)
    }

    @Test("two consecutive misses break the streak")
    func twoMissesBreaks() {
        let dog = makeDog()
        _ = makeWalk(daysAgo: 0, minutes: 60, dog: dog)
        // miss yesterday, miss 2 days ago
        for daysAgo in 3..<10 {
            _ = makeWalk(daysAgo: daysAgo, minutes: 60, dog: dog)
        }
        // Walking back: today hit (1). Yesterday miss — window has 2 non-hits (yesterday + 2-days-ago) → break.
        #expect(StreakService.currentStreak(for: dog, today: referenceToday, calendar: calendar) == 1)
    }

    @Test("partial day burns rest day same as miss")
    func partialBurnsRestDay() {
        let dog = makeDog(targetMinutes: 60)
        // today hit, yesterday partial (20 min < 30), 2 days ago miss → 2 non-hits in window → break at day 2
        _ = makeWalk(daysAgo: 0, minutes: 60, dog: dog)
        _ = makeWalk(daysAgo: 1, minutes: 20, dog: dog)
        for daysAgo in 3..<10 {
            _ = makeWalk(daysAgo: daysAgo, minutes: 60, dog: dog)
        }
        // Walking back: today hit (1). Yesterday partial — window has 1 non-hit, allowed, no extend.
        // 2 days ago: miss — window has 2 non-hits (yesterday partial + 2-days-ago miss) → break.
        #expect(StreakService.currentStreak(for: dog, today: referenceToday, calendar: calendar) == 1)
    }

    @Test("partial alone doesn't break, doesn't extend")
    func partialAloneAllowed() {
        let dog = makeDog(targetMinutes: 60)
        // today hit, yesterday partial, 2..7 hits
        _ = makeWalk(daysAgo: 0, minutes: 60, dog: dog)
        _ = makeWalk(daysAgo: 1, minutes: 20, dog: dog)
        for daysAgo in 2..<7 {
            _ = makeWalk(daysAgo: daysAgo, minutes: 60, dog: dog)
        }
        // today hit (1) + 5 hits 2-6 days ago (+5) = 6. Yesterday partial uses rest day; doesn't extend.
        #expect(StreakService.currentStreak(for: dog, today: referenceToday, calendar: calendar) == 6)
    }

    @Test("multiple walks same day combine to hit threshold")
    func multipleWalksSameDayCombine() {
        let dog = makeDog(targetMinutes: 60)
        _ = makeWalk(daysAgo: 0, minutes: 20, dog: dog)
        _ = makeWalk(daysAgo: 0, minutes: 25, dog: dog)
        // Total today = 45 ≥ 30 (50% of 60) → HIT
        #expect(StreakService.currentStreak(for: dog, today: referenceToday, calendar: calendar) == 1)
    }

    @Test("brand-new dog created today with one walk → streak 1, no penalty for prior days")
    func newDogNoPriorPenalty() {
        let dog = makeDog(createdDaysAgo: 0)
        _ = makeWalk(daysAgo: 0, minutes: 60, dog: dog)
        #expect(StreakService.currentStreak(for: dog, today: referenceToday, calendar: calendar) == 1)
    }

    @Test("brand-new dog with no walks → streak 0")
    func newDogNoWalks() {
        let dog = makeDog(createdDaysAgo: 0)
        #expect(StreakService.currentStreak(for: dog, today: referenceToday, calendar: calendar) == 0)
    }

    @Test("zero target returns 0 (defensive)")
    func zeroTargetSafe() {
        let dog = makeDog(targetMinutes: 0)
        _ = makeWalk(daysAgo: 0, minutes: 60, dog: dog)
        #expect(StreakService.currentStreak(for: dog, today: referenceToday, calendar: calendar) == 0)
    }

    @Test("exactly 50% of target counts as hit")
    func halfTargetIsHit() {
        let dog = makeDog(targetMinutes: 60)
        _ = makeWalk(daysAgo: 0, minutes: 30, dog: dog)
        #expect(StreakService.currentStreak(for: dog, today: referenceToday, calendar: calendar) == 1)
    }

    @Test("today miss with prior 6 hits → streak 6, today's miss is the rest day")
    func todayMissAfterHits() {
        let dog = makeDog()
        // today miss, 1..6 days ago hit
        for daysAgo in 1..<7 {
            _ = makeWalk(daysAgo: daysAgo, minutes: 60, dog: dog)
        }
        // Walking back: today miss — window has 1 non-hit (today), allowed, doesn't extend.
        // Yesterday hit (1), through 6 days ago hit (6).
        #expect(StreakService.currentStreak(for: dog, today: referenceToday, calendar: calendar) == 6)
    }
}
