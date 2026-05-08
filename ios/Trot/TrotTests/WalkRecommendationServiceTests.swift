import Testing
import Foundation
@testable import Trot

@Suite("WalkRecommendationService")
struct WalkRecommendationServiceTests {
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/London") ?? .gmt
        return cal
    }()

    private func date(year: Int, month: Int, day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = hour; c.minute = minute
        return calendar.date(from: c) ?? .now
    }

    private func dog(
        brachycephalic: Bool = false,
        arthritis: Bool = false,
        windows: [WalkSlot] = [.earlyMorning, .lunch, .afternoon, .evening]
    ) -> Dog {
        let d = Dog(
            name: "Test",
            breedPrimary: "Mixed",
            dateOfBirth: date(year: 2022, month: 1, day: 1),
            weightKg: 12,
            sex: .female,
            isNeutered: true,
            activityLevel: .moderate
        )
        d.isBrachycephalic = brachycephalic
        d.hasArthritis = arthritis
        d.walkWindows = windows.map { WalkWindow(slot: $0, enabled: true) }
        return d
    }

    private func snapshot(
        hour: Int,
        tempC: Double = 14,
        precip: Int = 0,
        wind: Double = 8,
        code: Int = 1
    ) -> HourlySnapshot {
        HourlySnapshot(
            time: date(year: 2026, month: 5, day: 11, hour: hour),
            temperatureC: tempC,
            precipitationProbability: precip,
            weatherCodeRaw: code,
            windSpeedKmh: wind
        )
    }

    private func forecast(_ snapshots: [HourlySnapshot]) -> WeatherForecast {
        WeatherForecast(
            location: WeatherLocation(postcode: "SW1A1AA", latitude: 51.5, longitude: -0.1, displayName: "London, UK"),
            hourly: snapshots,
            fetchedAt: date(year: 2026, month: 5, day: 11, hour: 6)
        )
    }

    // MARK: - Empty / fallback

    @Test("returns nil when forecast is empty")
    func emptyForecast() {
        let now = date(year: 2026, month: 5, day: 11, hour: 7)
        let rec = WalkRecommendationService.recommend(
            for: dog(),
            forecast: forecast([]),
            now: now,
            calendar: calendar
        )
        #expect(rec == nil)
    }

    @Test("returns nil when every hour is in the past")
    func allInPast() {
        let now = date(year: 2026, month: 5, day: 11, hour: 22)
        // Snapshots at 6am-9am — all before `now`.
        let snaps = (6..<10).map { snapshot(hour: $0) }
        let rec = WalkRecommendationService.recommend(
            for: dog(),
            forecast: forecast(snaps),
            now: now,
            calendar: calendar
        )
        #expect(rec == nil)
    }

    // MARK: - Picking the right window

    @Test("picks the dry, comfortable window over the rainy one")
    func picksDryWindow() {
        let now = date(year: 2026, month: 5, day: 11, hour: 7)
        // 8am-9am: heavy rain. 11am-1pm: clear, comfortable.
        let snaps: [HourlySnapshot] = [
            snapshot(hour: 8, tempC: 12, precip: 90, code: 65),
            snapshot(hour: 9, tempC: 12, precip: 90, code: 65),
            snapshot(hour: 11, tempC: 16, precip: 5, code: 1),
            snapshot(hour: 12, tempC: 17, precip: 5, code: 1),
            snapshot(hour: 13, tempC: 17, precip: 5, code: 1),
        ]
        let rec = WalkRecommendationService.recommend(
            for: dog(),
            forecast: forecast(snaps),
            now: now,
            calendar: calendar
        )
        #expect(rec != nil)
        #expect(calendar.component(.hour, from: rec!.start) == 11, "should pick the 11am window")
        #expect(rec!.durationHours >= 2)
    }

    @Test("brachycephalic dog avoids the hottest hours")
    func brachyAvoidsHeat() {
        let now = date(year: 2026, month: 5, day: 11, hour: 6)
        // Cool morning (good for a brachy dog) vs hot afternoon (bad).
        let snaps: [HourlySnapshot] = [
            snapshot(hour: 7, tempC: 14, code: 1),
            snapshot(hour: 8, tempC: 15, code: 1),
            // Afternoon: 26°C is well above brachy ceiling (18°C).
            snapshot(hour: 14, tempC: 26, code: 0),
            snapshot(hour: 15, tempC: 26, code: 0),
            snapshot(hour: 16, tempC: 26, code: 0),
        ]
        let rec = WalkRecommendationService.recommend(
            for: dog(brachycephalic: true),
            forecast: forecast(snaps),
            now: now,
            calendar: calendar
        )
        #expect(rec != nil)
        let pickedHour = calendar.component(.hour, from: rec!.start)
        #expect(pickedHour == 7 || pickedHour == 8, "should pick the cooler morning window")
    }

    @Test("sunshine beats overcast even outside enabled walk windows")
    func sunshineBeatsOvercast() {
        let now = date(year: 2026, month: 5, day: 11, hour: 6)
        // Only evening is enabled.
        let d = dog(windows: [.evening])

        // Afternoon is clear and mild (out of window). Evening is overcast
        // (in window). Per the May 2026 revision: walk windows are a hint,
        // not a hard cap. People in the UK will choose sunshine over a
        // stated preference. Earlier this test asserted the opposite —
        // that windows hard-capped the recommendation — and the result
        // felt anti-engagement (the user complained the tile picked an
        // overcast evening when 10am-7pm was sunny).
        let snaps: [HourlySnapshot] = [
            snapshot(hour: 14, tempC: 16, precip: 0, code: 0),  // afternoon, clear
            snapshot(hour: 15, tempC: 16, precip: 0, code: 0),
            snapshot(hour: 18, tempC: 14, precip: 0, code: 3),  // evening, overcast
            snapshot(hour: 19, tempC: 14, precip: 0, code: 3),
            snapshot(hour: 20, tempC: 13, precip: 0, code: 3),
        ]
        let rec = WalkRecommendationService.recommend(
            for: d,
            forecast: forecast(snaps),
            now: now,
            calendar: calendar
        )
        #expect(rec != nil)
        let pickedHour = calendar.component(.hour, from: rec!.start)
        #expect((14...15).contains(pickedHour), "sunshine wins regardless of windows")
    }

    @Test("long sunny stretch beats a short top-scoring slice")
    func longSunnyStretchWins() {
        let now = date(year: 2026, month: 5, day: 11, hour: 9)
        // Evening is enabled — gets the +1 in-window bonus on top of the
        // weather-driven score. Without the new tolerance-based bestRun,
        // the four enabled-evening hours would beat the eight-hour
        // afternoon stretch despite the afternoon being equally sunny.
        // Tests the May 2026 fix: long decent stretches dominate.
        let d = dog(windows: [.evening])
        var snaps: [HourlySnapshot] = []
        for h in 10...17 {
            snaps.append(snapshot(hour: h, tempC: 16, precip: 0, code: 0))   // 8h clear, out of window
        }
        for h in 18...19 {
            snaps.append(snapshot(hour: h, tempC: 15, precip: 0, code: 0))   // 2h clear, in window
        }
        let rec = WalkRecommendationService.recommend(
            for: d,
            forecast: forecast(snaps),
            now: now,
            calendar: calendar
        )
        #expect(rec != nil)
        let pickedHour = calendar.component(.hour, from: rec!.start)
        #expect(pickedHour == 10, "should pick the long sunny stretch starting at 10am")
        #expect(rec!.durationHours >= 6, "should keep the run long, not collapse to the in-window slice")
    }

    @Test("dog with no configured windows still gets a recommendation")
    func noWindowsConfigured() {
        let now = date(year: 2026, month: 5, day: 11, hour: 7)
        let d = dog(windows: [])
        let snaps: [HourlySnapshot] = [
            snapshot(hour: 11, tempC: 16, precip: 5, code: 1),
            snapshot(hour: 12, tempC: 16, precip: 5, code: 1),
        ]
        let rec = WalkRecommendationService.recommend(
            for: d,
            forecast: forecast(snaps),
            now: now,
            calendar: calendar
        )
        // Should not be nil — we don't require windows to be set.
        #expect(rec != nil)
    }

    // MARK: - Headline copy sanity

    @Test("headline names temperature and includes 'now' for imminent windows")
    func headlineImminent() {
        let now = date(year: 2026, month: 5, day: 11, hour: 11)
        let snaps: [HourlySnapshot] = [
            snapshot(hour: 11, tempC: 15, code: 1),
            snapshot(hour: 12, tempC: 16, code: 1),
        ]
        guard let rec = WalkRecommendationService.recommend(
            for: dog(),
            forecast: forecast(snaps),
            now: now,
            calendar: calendar
        ) else {
            Issue.record("Expected a recommendation"); return
        }
        #expect(rec.headline.contains("now"))
        #expect(rec.headline.contains("15°") || rec.headline.contains("16°"))
    }
}
