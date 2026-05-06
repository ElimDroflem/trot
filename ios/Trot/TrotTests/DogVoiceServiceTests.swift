import Testing
import Foundation
@testable import Trot

@Suite("DogVoiceService")
struct DogVoiceServiceTests {
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
        return cal
    }()

    private func date(year: Int = 2026, month: Int = 5, day: Int = 12, hour: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = hour
        return calendar.date(from: c) ?? .now
    }

    private func makeDog(
        name: String = "Luna",
        targetMinutes: Int = 60,
        windows: [WalkSlot] = []
    ) -> Dog {
        let dog = Dog(
            name: name,
            breedPrimary: "Mixed",
            dateOfBirth: Date(timeIntervalSince1970: 0),
            weightKg: 10,
            sex: .female,
            isNeutered: true,
            dailyTargetMinutes: targetMinutes
        )
        dog.walkWindows = windows.map { WalkWindow(slot: $0, enabled: true) }
        return dog
    }

    @discardableResult
    private func addWalk(to dog: Dog, on day: Date, hour: Int = 9, minutes: Int = 30) -> Walk {
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
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

    // MARK: - Precedence ladder

    @Test("target met: praise (single walk)")
    func targetMetSingle() {
        let dog = makeDog()
        let now = date(hour: 18)
        addWalk(to: dog, on: now, minutes: 60)
        let line = DogVoiceService.currentLine(for: dog, now: now, calendar: calendar)
        #expect(line == "Luna sorted that in one. Good walk.")
    }

    @Test("target met: praise (multiple walks)")
    func targetMetMultiple() {
        let dog = makeDog()
        let now = date(hour: 18)
        addWalk(to: dog, on: now, hour: 8, minutes: 35)
        addWalk(to: dog, on: now, hour: 14, minutes: 30)
        let line = DogVoiceService.currentLine(for: dog, now: now, calendar: calendar)
        #expect(line == "Luna's done for the day. Good work.")
    }

    @Test("late night, no walks: calm acceptance, no nudge")
    func lateNightNoWalks() {
        let dog = makeDog()
        let line = DogVoiceService.currentLine(for: dog, now: date(hour: 23), calendar: calendar)
        #expect(line == "Luna's settling. Tomorrow's a fresh start.")
    }

    @Test("partial progress (≥50%): top-up phrasing")
    func halfTargetTopUp() {
        let dog = makeDog()
        let now = date(hour: 16)
        addWalk(to: dog, on: now, hour: 8, minutes: 35)
        let line = DogVoiceService.currentLine(for: dog, now: now, calendar: calendar)
        #expect(line == "Luna's had 35 minutes today. A short top-up rounds it off.")
    }

    @Test("low progress (<50%): room-for-more phrasing")
    func underHalfRoomForMore() {
        let dog = makeDog()
        let now = date(hour: 14)
        addWalk(to: dog, on: now, hour: 8, minutes: 15)
        let line = DogVoiceService.currentLine(for: dog, now: now, calendar: calendar)
        #expect(line == "Luna's had 15 minutes so far. Room for more.")
    }

    @Test("no walks, currently inside enabled morning window: window-open nudge")
    func morningWindowOpen() {
        let dog = makeDog(windows: [.earlyMorning])
        let line = DogVoiceService.currentLine(for: dog, now: date(hour: 7), calendar: calendar)
        #expect(line == "Luna's morning window is open. Quiet so far.")
    }

    @Test("no walks, in evening window: evening-open nudge")
    func eveningWindowOpen() {
        let dog = makeDog(windows: [.evening])
        let line = DogVoiceService.currentLine(for: dog, now: date(hour: 19), calendar: calendar)
        #expect(line == "Luna's evening window is open. Still light enough.")
    }

    @Test("no walks, future enabled window today: anticipation phrasing")
    func futureWindow() {
        // 9:30am, evening window enabled, no current window match (9-11 is gap)
        let dog = makeDog(windows: [.evening])
        let line = DogVoiceService.currentLine(for: dog, now: date(hour: 10), calendar: calendar)
        #expect(line == "Luna's evening window opens at 6pm.")
    }

    @Test("no walks, no enabled windows, morning fallback")
    func morningFallback() {
        let dog = makeDog(windows: [])
        let line = DogVoiceService.currentLine(for: dog, now: date(hour: 7), calendar: calendar)
        #expect(line == "Luna hasn't been out yet. A morning walk's a gentle start.")
    }

    @Test("no walks, no enabled windows, lunchtime fallback")
    func lunchFallback() {
        let dog = makeDog(windows: [])
        let line = DogVoiceService.currentLine(for: dog, now: date(hour: 12), calendar: calendar)
        #expect(line == "Luna's been quiet all morning. Lunchtime walks count.")
    }

    @Test("no walks, no enabled windows, afternoon fallback")
    func afternoonFallback() {
        let dog = makeDog(windows: [])
        let line = DogVoiceService.currentLine(for: dog, now: date(hour: 15), calendar: calendar)
        #expect(line == "Luna's still waiting for today's walk.")
    }

    @Test("no walks, no enabled windows, evening fallback")
    func eveningFallback() {
        let dog = makeDog(windows: [])
        let line = DogVoiceService.currentLine(for: dog, now: date(hour: 19), calendar: calendar)
        #expect(line == "Luna hasn't been out today. Evening's the time.")
    }

    @Test("empty dog name uses 'Your dog' fallback")
    func emptyName() {
        let dog = makeDog(name: "")
        let line = DogVoiceService.currentLine(for: dog, now: date(hour: 7), calendar: calendar)
        #expect(line.starts(with: "Your dog"))
    }

    @Test("zero target is defensive (treated as no progress, falls through to fallback)")
    func zeroTargetDefensive() {
        let dog = makeDog(targetMinutes: 0)
        let now = date(hour: 7)
        addWalk(to: dog, on: now, minutes: 30)
        let line = DogVoiceService.currentLine(for: dog, now: now, calendar: calendar)
        // 30 minutes logged but target is 0 — percent = 0, treated as "had X minutes" branch
        #expect(line.contains("30 minutes"))
    }

    @Test("brand voice: no exclamation marks anywhere")
    func brandVoiceNoBangs() {
        // Sample several states to confirm no rule violations slipped in
        let dog = makeDog(windows: [.earlyMorning, .evening])
        for hour in [7, 12, 15, 19, 23] {
            let line = DogVoiceService.currentLine(for: dog, now: date(hour: hour), calendar: calendar)
            #expect(!line.contains("!"), "no exclamation marks per brand.md (hour: \(hour))")
            #expect(!line.lowercased().contains("pawsome"), "no 'pawsome' (hour: \(hour))")
            #expect(!line.contains("—"), "no em dashes in copy (hour: \(hour))")
        }
    }
}
