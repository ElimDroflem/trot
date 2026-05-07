import Testing
import Foundation
@testable import Trot

@Suite("DogInsightsService")
struct DogInsightsServiceTests {
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
        return cal
    }()

    private let referenceToday: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 5; c.day = 12; c.hour = 12
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
        return cal.date(from: c) ?? .now
    }()

    private func makeDog(
        breed: String = "Beagle",
        ageYears: Int = 3,
        targetMinutes: Int = 60,
        arthritis: Bool = false,
        hipDysplasia: Bool = false,
        brachycephalic: Bool = false
    ) -> Dog {
        let dob = calendar.date(byAdding: .year, value: -ageYears, to: referenceToday) ?? referenceToday
        let dog = Dog(
            name: "Test",
            breedPrimary: breed,
            dateOfBirth: dob,
            weightKg: 12,
            sex: .female,
            isNeutered: true,
            dailyTargetMinutes: targetMinutes
        )
        dog.hasArthritis = arthritis
        dog.hasHipDysplasia = hipDysplasia
        dog.isBrachycephalic = brachycephalic
        return dog
    }

    private func addWalk(daysAgo: Int, hour: Int = 16, minutes: Int, to dog: Dog) {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: referenceToday) ?? referenceToday
        let withHour = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
        let walk = Walk(
            startedAt: withHour,
            durationMinutes: minutes,
            distanceMeters: nil,
            source: .manual,
            notes: "",
            dogs: [dog]
        )
        dog.walks = (dog.walks ?? []) + [walk]
    }

    @Test("empty dog returns no insights")
    func emptyDog() {
        let dog = makeDog()
        let out = DogInsightsService.insights(for: dog, now: referenceToday, calendar: calendar)
        #expect(out.isEmpty)
    }

    @Test("under-target dog gets a 'room to walk more' volume insight")
    func underTarget() {
        let dog = makeDog(targetMinutes: 60)
        // 7 days × 20 min = 140 min, average 20/day. Below 70% of 60 (=42).
        for d in 0..<7 { addWalk(daysAgo: d, minutes: 20, to: dog) }
        let out = DogInsightsService.insights(for: dog, now: referenceToday, calendar: calendar)
        let volume = out.first { $0.kind == .volume }
        #expect(volume?.id == "volume.under")
        #expect(volume?.body.contains("60 min") ?? false)
    }

    @Test("on-target dog gets a 'on the breed mark' volume insight")
    func onTarget() {
        let dog = makeDog(targetMinutes: 60)
        // 7 days × 60 min = 420 min, average 60/day.
        for d in 0..<7 { addWalk(daysAgo: d, minutes: 60, to: dog) }
        let out = DogInsightsService.insights(for: dog, now: referenceToday, calendar: calendar)
        let volume = out.first { $0.kind == .volume }
        #expect(volume?.id == "volume.on")
    }

    @Test("over-target dog gets a 'plenty of mileage' insight")
    func overTarget() {
        let dog = makeDog(targetMinutes: 60)
        // 7 days × 100 min = 700, average 100, > 1.4 × 60 = 84.
        for d in 0..<7 { addWalk(daysAgo: d, minutes: 100, to: dog) }
        let out = DogInsightsService.insights(for: dog, now: referenceToday, calendar: calendar)
        let volume = out.first { $0.kind == .volume }
        #expect(volume?.id == "volume.over")
    }

    @Test("arthritic dog surfaces a joint-care health insight")
    func arthriticDog() {
        let dog = makeDog(arthritis: true)
        addWalk(daysAgo: 0, minutes: 30, to: dog)
        let out = DogInsightsService.insights(for: dog, now: referenceToday, calendar: calendar)
        let health = out.first { $0.id == "health.joints" }
        #expect(health != nil)
    }

    @Test("brachycephalic dog surfaces a heat-warning health insight")
    func brachycephalicDog() {
        let dog = makeDog(brachycephalic: true)
        addWalk(daysAgo: 0, minutes: 30, to: dog)
        let out = DogInsightsService.insights(for: dog, now: referenceToday, calendar: calendar)
        let health = out.first { $0.id == "health.brachy" }
        #expect(health != nil)
    }

    @Test("puppy gets life-stage advice")
    func puppy() {
        let dog = makeDog(ageYears: 0)  // 0 years = puppy
        addWalk(daysAgo: 0, minutes: 10, to: dog)
        let out = DogInsightsService.insights(for: dog, now: referenceToday, calendar: calendar)
        let stage = out.first { $0.kind == .lifeStage }
        #expect(stage?.id == "stage.puppy")
    }

    @Test("senior gets life-stage advice")
    func senior() {
        let dog = makeDog(ageYears: 9)  // ≥8 years
        addWalk(daysAgo: 0, minutes: 30, to: dog)
        let out = DogInsightsService.insights(for: dog, now: referenceToday, calendar: calendar)
        let stage = out.first { $0.kind == .lifeStage }
        #expect(stage?.kind == .lifeStage)
        #expect(stage?.id.hasPrefix("stage.senior") ?? false)
    }

    @Test("adult dogs don't get a generic life-stage card")
    func adultNoStageCard() {
        let dog = makeDog(ageYears: 3)
        addWalk(daysAgo: 0, minutes: 60, to: dog)
        let out = DogInsightsService.insights(for: dog, now: referenceToday, calendar: calendar)
        #expect(!out.contains(where: { $0.kind == .lifeStage }))
    }

    @Test("strong time-of-day pattern surfaces an insight")
    func timeOfDayPattern() {
        let dog = makeDog()
        // 10 walks in the afternoon (hour 14), 1 in the evening — clear pattern.
        for d in 0..<10 { addWalk(daysAgo: d, hour: 14, minutes: 30, to: dog) }
        addWalk(daysAgo: 11, hour: 19, minutes: 30, to: dog)
        let out = DogInsightsService.insights(for: dog, now: referenceToday, calendar: calendar)
        #expect(out.contains(where: { $0.kind == .timeOfDay }))
    }

    @Test("scattered walks don't trigger a time-of-day pattern")
    func noTimeOfDayPattern() {
        let dog = makeDog()
        // Spread across morning / afternoon / evening — no single bucket dominates.
        addWalk(daysAgo: 0, hour: 8, minutes: 30, to: dog)
        addWalk(daysAgo: 1, hour: 14, minutes: 30, to: dog)
        addWalk(daysAgo: 2, hour: 19, minutes: 30, to: dog)
        addWalk(daysAgo: 3, hour: 9, minutes: 30, to: dog)
        addWalk(daysAgo: 4, hour: 15, minutes: 30, to: dog)
        addWalk(daysAgo: 5, hour: 20, minutes: 30, to: dog)
        let out = DogInsightsService.insights(for: dog, now: referenceToday, calendar: calendar)
        #expect(!out.contains(where: { $0.kind == .timeOfDay }))
    }

    @Test("output is capped at three insights")
    func capAtThree() {
        let dog = makeDog(arthritis: true, hipDysplasia: true, brachycephalic: true)
        // Lots of conditions + clear pattern + on-target volume = potentially many.
        for d in 0..<10 { addWalk(daysAgo: d, hour: 8, minutes: 60, to: dog) }
        let out = DogInsightsService.insights(for: dog, now: referenceToday, calendar: calendar)
        #expect(out.count <= 3)
    }
}
