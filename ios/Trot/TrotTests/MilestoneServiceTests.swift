import Testing
import Foundation
@testable import Trot

@Suite("MilestoneService")
struct MilestoneServiceTests {
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
        return cal
    }()

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

    // MARK: - Per-beat eligibility

    @Test("brand-new dog with no walks fires nothing")
    func newDogNoBeats() {
        let dog = makeDog(createdDaysAgo: 0)
        let eligible = MilestoneService.eligible(for: dog, today: referenceToday, calendar: calendar)
        #expect(eligible.isEmpty)
    }

    @Test("first walk alone fires firstWalk only")
    func firstWalkOnly() {
        let dog = makeDog(targetMinutes: 60, createdDaysAgo: 0)
        addWalk(daysAgo: 0, minutes: 10, to: dog)
        let eligible = MilestoneService.eligible(for: dog, today: referenceToday, calendar: calendar)
        #expect(eligible == [.firstWalk])
    }

    @Test("a walk that hits half-target fires firstWalk + firstHalfTargetDay")
    func halfTargetCascade() {
        let dog = makeDog(targetMinutes: 60, createdDaysAgo: 0)
        addWalk(daysAgo: 0, minutes: 30, to: dog)
        let eligible = MilestoneService.eligible(for: dog, today: referenceToday, calendar: calendar)
        #expect(eligible.contains(.firstWalk))
        #expect(eligible.contains(.firstHalfTargetDay))
        #expect(!eligible.contains(.firstFullTargetDay))
    }

    @Test("a walk hitting full target fires the full cascade up to fullTarget")
    func fullTargetCascade() {
        let dog = makeDog(targetMinutes: 60, createdDaysAgo: 0)
        addWalk(daysAgo: 0, minutes: 60, to: dog)
        let eligible = MilestoneService.eligible(for: dog, today: referenceToday, calendar: calendar)
        #expect(eligible.contains(.firstWalk))
        #expect(eligible.contains(.firstHalfTargetDay))
        #expect(eligible.contains(.firstFullTargetDay))
    }

    @Test("multiple walks combining to half-target on a single day still count")
    func combinedDayHitsHalfTarget() {
        let dog = makeDog(targetMinutes: 60, createdDaysAgo: 0)
        addWalk(daysAgo: 0, minutes: 15, to: dog)
        addWalk(daysAgo: 0, minutes: 18, to: dog)
        let eligible = MilestoneService.eligible(for: dog, today: referenceToday, calendar: calendar)
        #expect(eligible.contains(.firstHalfTargetDay))
    }

    @Test("walks across two days, neither hitting half, do not combine across days")
    func walksAcrossDaysDoNotCombine() {
        let dog = makeDog(targetMinutes: 60, createdDaysAgo: 1)
        addWalk(daysAgo: 1, minutes: 20, to: dog)
        addWalk(daysAgo: 0, minutes: 20, to: dog)
        let eligible = MilestoneService.eligible(for: dog, today: referenceToday, calendar: calendar)
        #expect(eligible.contains(.firstWalk))
        #expect(!eligible.contains(.firstHalfTargetDay))
    }

    @Test("first 100 lifetime minutes")
    func first100Minutes() {
        let dog = makeDog(targetMinutes: 60, createdDaysAgo: 5)
        addWalk(daysAgo: 5, minutes: 30, to: dog)
        addWalk(daysAgo: 4, minutes: 30, to: dog)
        addWalk(daysAgo: 3, minutes: 30, to: dog)
        var eligible = MilestoneService.eligible(for: dog, today: referenceToday, calendar: calendar)
        #expect(!eligible.contains(.first100LifetimeMinutes), "90 minutes is not 100")
        addWalk(daysAgo: 2, minutes: 10, to: dog)
        eligible = MilestoneService.eligible(for: dog, today: referenceToday, calendar: calendar)
        #expect(eligible.contains(.first100LifetimeMinutes))
    }

    @Test("first 3-day streak fires when StreakService returns ≥3")
    func first3DayStreak() {
        let dog = makeDog(targetMinutes: 60, createdDaysAgo: 5)
        // Three consecutive days hitting the target
        addWalk(daysAgo: 2, minutes: 60, to: dog)
        addWalk(daysAgo: 1, minutes: 60, to: dog)
        addWalk(daysAgo: 0, minutes: 60, to: dog)
        let eligible = MilestoneService.eligible(for: dog, today: referenceToday, calendar: calendar)
        #expect(eligible.contains(.first3DayStreak))
    }

    @Test("two consecutive hits do not yet fire first3DayStreak")
    func twoDayStreakNotEnough() {
        let dog = makeDog(targetMinutes: 60, createdDaysAgo: 5)
        addWalk(daysAgo: 1, minutes: 60, to: dog)
        addWalk(daysAgo: 0, minutes: 60, to: dog)
        let eligible = MilestoneService.eligible(for: dog, today: referenceToday, calendar: calendar)
        #expect(!eligible.contains(.first3DayStreak))
    }

    /// Streak tier matrix — each consecutive-day count fires the right tier and no higher.
    /// Folded into one parameterised test per the new "targeted tests during iteration" rule.
    @Test(arguments: [
        // (consecutiveHitDays, expectedTiers, unexpectedTiers)
        (3,  [MilestoneCode.first3DayStreak], [MilestoneCode.streak7Days, .streak14Days, .streak30Days]),
        (7,  [MilestoneCode.first3DayStreak, .streak7Days], [MilestoneCode.streak14Days, .streak30Days]),
        (14, [MilestoneCode.first3DayStreak, .streak7Days, .streak14Days], [MilestoneCode.streak30Days]),
        (30, [MilestoneCode.first3DayStreak, .streak7Days, .streak14Days, .streak30Days], []),
    ])
    func streakTierMatrix(
        consecutiveDays: Int,
        expected: [MilestoneCode],
        unexpected: [MilestoneCode]
    ) {
        let dog = makeDog(targetMinutes: 60, createdDaysAgo: consecutiveDays + 1)
        for offset in 0..<consecutiveDays {
            addWalk(daysAgo: offset, minutes: 60, to: dog)
        }
        let eligible = MilestoneService.eligible(for: dog, today: referenceToday, calendar: calendar)
        for tier in expected {
            #expect(eligible.contains(tier), "\(consecutiveDays)-day streak should fire \(tier.rawValue)")
        }
        for tier in unexpected {
            #expect(!eligible.contains(tier), "\(consecutiveDays)-day streak should NOT fire \(tier.rawValue)")
        }
    }

    @Test("firstWeek does not fire before day 7")
    func firstWeekNotYet() {
        let dog = makeDog(createdDaysAgo: 6)
        let eligible = MilestoneService.eligible(for: dog, today: referenceToday, calendar: calendar)
        #expect(!eligible.contains(.firstWeek))
    }

    @Test("firstWeek fires exactly at day 7")
    func firstWeekFires() {
        let dog = makeDog(createdDaysAgo: 7)
        let eligible = MilestoneService.eligible(for: dog, today: referenceToday, calendar: calendar)
        #expect(eligible.contains(.firstWeek))
    }

    // MARK: - newMilestones (eligible − already-fired)

    @Test("newMilestones returns only beats not already in firedMilestones")
    func newMilestonesDiffsCorrectly() {
        let dog = makeDog(targetMinutes: 60, createdDaysAgo: 0)
        addWalk(daysAgo: 0, minutes: 60, to: dog)
        // Pretend we've already shown firstWalk
        dog.firedMilestones = [MilestoneCode.firstWalk.rawValue]
        let new = MilestoneService.newMilestones(for: dog, today: referenceToday, calendar: calendar)
        #expect(!new.contains(.firstWalk))
        #expect(new.contains(.firstHalfTargetDay))
        #expect(new.contains(.firstFullTargetDay))
    }

    @Test("newMilestones is sorted by sortIndex (narrative order)")
    func newMilestonesSorted() {
        let dog = makeDog(targetMinutes: 60, createdDaysAgo: 7)
        // 7 days ago, then 100+ minutes accumulated, full streak running today
        for offset in 0...2 {
            addWalk(daysAgo: offset, minutes: 60, to: dog)
        }
        let new = MilestoneService.newMilestones(for: dog, today: referenceToday, calendar: calendar)
        let sortedIndices = new.map(\.sortIndex)
        #expect(sortedIndices == sortedIndices.sorted(), "result is in narrative order")
        // sanity: this dog should hit several beats at once
        #expect(new.count >= 5)
    }

    @Test("markFired records new codes without duplicating")
    func markFiredDedupes() {
        let dog = makeDog()
        MilestoneService.markFired([.firstWalk, .firstHalfTargetDay], on: dog)
        #expect(dog.firedMilestones.contains(MilestoneCode.firstWalk.rawValue))
        #expect(dog.firedMilestones.contains(MilestoneCode.firstHalfTargetDay.rawValue))

        // Re-mark the same codes plus one new
        MilestoneService.markFired([.firstWalk, .firstFullTargetDay], on: dog)
        let firstWalkCount = dog.firedMilestones.filter { $0 == MilestoneCode.firstWalk.rawValue }.count
        #expect(firstWalkCount == 1, "no duplicate entries")
        #expect(dog.firedMilestones.contains(MilestoneCode.firstFullTargetDay.rawValue))
    }

    // MARK: - Defensive

    @Test("zero target skips target-percentage beats")
    func zeroTargetIsDefensive() {
        let dog = makeDog(targetMinutes: 0, createdDaysAgo: 0)
        addWalk(daysAgo: 0, minutes: 30, to: dog)
        let eligible = MilestoneService.eligible(for: dog, today: referenceToday, calendar: calendar)
        #expect(eligible.contains(.firstWalk))
        #expect(!eligible.contains(.firstHalfTargetDay))
        #expect(!eligible.contains(.firstFullTargetDay))
    }
}
