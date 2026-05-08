import Foundation

/// Combines a dog's walk windows + the day's hourly forecast into a single
/// "best window today" recommendation. Pure scoring, no networking.
///
/// Philosophy (May 2026 revision): walk windows are a *hint*, not a hard
/// cap. People in the UK will choose sunshine over a stated preference
/// every time. So sunshine outside the user's window beats overcast inside
/// it, and the picker rewards a long contiguous run of decent weather over
/// a short run of best weather — a four-hour evening slot can't win over a
/// nine-hour clear stretch through the middle of the day, even if every
/// evening hour scores marginally higher.
///
/// Scoring per hour:
///   +1  inside one of the dog's enabled walk windows (token preference)
///   +4  clear sky (the bias toward sunny hours)
///   +2  partly cloudy
///   +3  temperature in the dog's comfort band
///   -3  temperature just above comfort upper bound (e.g. 22.1°C+ for normal dogs)
///   -6  temperature dangerously above comfort (≥+4 over upper bound)
///   -3  temperature uncomfortably cold
///   -8  precipitation probability ≥ 70%
///   -3  precipitation probability 40–69%
///   -2  wind ≥ 30 km/h
///   -2  drizzle category penalty
///   -4  rain category penalty
///   -6  thunder or snow category penalty
///   -1  fog category penalty
///
/// Recommendation = the longest contiguous run of hours where score is
/// within 4 of the top score AND ≥ 5. Falls back to the single best hour if
/// no run qualifies. Length wins on ties (a six-hour decent window beats a
/// six-hour decent window starting later in the day, but a short
/// excellent window can still win if everything else is poor).
///
/// The reason string is templated, deterministic, and short — designed to read
/// well at a glance on a Today-tab tile. LLM flavour can layer on later.
enum WalkRecommendationService {

    struct Recommendation: Equatable {
        let start: Date
        /// End of the recommended window — `start + durationHours` hours.
        /// Surfacing this lets the headline say "from 1pm to 3pm" rather
        /// than just naming a single start hour, and lets a downstream
        /// reminder schedule a notification at `start` knowing the window
        /// length.
        let end: Date
        let durationHours: Int
        let category: WeatherCategory
        let temperatureC: Double
        /// Short, glanceable rationale. e.g. "Best 1pm to 3pm. Sunny, 18°."
        let headline: String
        /// Slightly longer reason that can sit under the headline if there's room.
        let detail: String
    }

    /// Build a recommendation. Returns nil if the forecast is empty or every hour
    /// is past the cutoff (the "look-ahead" window is anchored to `now`).
    static func recommend(
        for dog: Dog,
        forecast: WeatherForecast,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Recommendation? {
        let upcoming = forecast.hourly.filter { $0.time >= calendar.startOfHour(for: now) }
        guard !upcoming.isEmpty else { return nil }

        let scores = upcoming.map { hour -> (HourlySnapshot, Int) in
            (hour, score(hour: hour, for: dog, calendar: calendar))
        }

        // Pick the contiguous run of the highest-scoring hours (≥2h). Ties resolved
        // by earliest start so users get told to walk *now* when possible.
        guard let bestUntrimmed = bestRun(in: scores, minLength: 2) ?? bestSingleHour(in: scores) else {
            return nil
        }
        // Cap the window length so a uniformly-excellent day produces a
        // believable "window" rather than "Best 10am to 12am" (which the
        // user reads as "all day" — and "all day" is not a window). Nine
        // hours matches the natural UK reading: 10am-7pm style.
        let maxRunLength = 9
        let best = Array(bestUntrimmed.prefix(maxRunLength))

        let first = best.first!.0
        let dur = best.count
        let end = calendar.date(byAdding: .hour, value: dur, to: first.time) ?? first.time

        // Use the modal category and median temperature across the whole
        // run for the displayed headline, not just the first hour. Without
        // this, a 9-hour run that starts partly-cloudy and goes clear
        // would say "Bright, 14°" when the user's actually getting a
        // mostly-sunny window — a misleading framing for the same data.
        let modalCategory = mode(of: best.map { $0.0.category }) ?? first.category
        let displayTemp = median(of: best.map { $0.0.temperatureC }) ?? first.temperatureC

        return Recommendation(
            start: first.time,
            end: end,
            durationHours: dur,
            category: modalCategory,
            temperatureC: displayTemp,
            headline: headline(
                start: first.time,
                end: end,
                durationHours: dur,
                category: modalCategory,
                temperatureC: displayTemp,
                now: now,
                calendar: calendar
            ),
            detail: detail(for: first, dog: dog)
        )
    }

    private static func mode<T: Hashable>(of values: [T]) -> T? {
        var counts: [T: Int] = [:]
        for v in values { counts[v, default: 0] += 1 }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    private static func median(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }

    // MARK: - Scoring

    private static func score(hour: HourlySnapshot, for dog: Dog, calendar: Calendar) -> Int {
        var s = 0

        if isInsideEnabledWindow(hour: hour, for: dog, calendar: calendar) {
            // Token nudge — earlier this was +5 and dominated weather, so a
            // four-hour "in window" cloudy stretch could beat a nine-hour
            // sunny clear-sky stretch. The user's intent is "best sunny
            // window today, with my windows as a tiebreaker," not "stay in
            // my window even if the weather is dim."
            s += 1
        }

        let comfort = comfortBand(for: dog)
        if (comfort.lowerBound...comfort.upperBound).contains(hour.temperatureC) {
            s += 3
        } else if hour.temperatureC > comfort.upperBound + 4 {
            // Dangerously hot.
            s -= 6
        } else if hour.temperatureC > comfort.upperBound {
            // Just above comfort upper bound — e.g. 22.1°C+ for a normal
            // dog. Earlier this only kicked in at +4 over (so 26°C+), which
            // meant a 23°C afternoon could still rank top. The user's rule:
            // never recommend an hour above the comfort cap.
            s -= 3
        } else if hour.temperatureC < comfort.lowerBound - 4 {
            s -= 3
        }

        switch hour.precipitationProbability {
        case 70...:    s -= 8
        case 40...69:  s -= 3
        default:       break
        }

        if hour.windSpeedKmh >= 30 { s -= 2 }

        // Sunny bias — frames the recommendation as "the best sunny window
        // today" rather than "the least bad weather window." Clear gets a
        // strong bump; partly cloudy a smaller one. Cloudy stays at zero.
        switch hour.category {
        case .clear:           s += 4
        case .partlyCloudy:    s += 2
        case .cloudy:          break
        case .fog:             s -= 1
        case .drizzle:         s -= 2
        case .rain:            s -= 4
        case .thunder, .snow:  s -= 6
        }

        return s
    }

    /// Find the longest contiguous run of "decent" hours.
    ///
    /// "Decent" = score is within `tolerance` of the top AND meets a
    /// minimum quality bar (`minQuality`). The tolerance lets a long
    /// stretch of slightly-lower-scoring hours win over a short stretch of
    /// top-scoring hours — which is the right shape for a "best walk
    /// window today" recommendation: a nine-hour clear-sky window through
    /// the middle of the day should beat a four-hour clear-sky window
    /// just because the four-hour slot happens to fall inside the user's
    /// preferred slot.
    ///
    /// The minimum-quality floor prevents the run from including hours that
    /// only look decent because the rest of the day is awful. If the best
    /// hour today scores +6, a run of +2 hours doesn't qualify just because
    /// they're "within tolerance" — they're not actually nice walking
    /// weather, they're just less bad. Without the floor, a grim
    /// rain-and-cold day would still pick a 6-hour "best window" of dim
    /// hours and pretend that's a recommendation.
    ///
    /// Length wins on ties; on a tie of equal length, the earlier run wins
    /// so users get told to walk sooner when possible.
    private static func bestRun(
        in scores: [(HourlySnapshot, Int)],
        minLength: Int,
        tolerance: Int = 4,
        minQuality: Int = 5
    ) -> [(HourlySnapshot, Int)]? {
        guard let topScore = scores.map(\.1).max(), topScore >= minQuality else {
            return nil
        }
        let threshold = max(topScore - tolerance, minQuality)

        var bestRun: [(HourlySnapshot, Int)] = []
        var current: [(HourlySnapshot, Int)] = []

        for entry in scores {
            if entry.1 >= threshold {
                current.append(entry)
                if current.count > bestRun.count { bestRun = current }
            } else {
                current = []
            }
        }

        return bestRun.count >= minLength ? bestRun : nil
    }

    private static func bestSingleHour(
        in scores: [(HourlySnapshot, Int)]
    ) -> [(HourlySnapshot, Int)]? {
        guard let top = scores.max(by: { $0.1 < $1.1 }), top.1 > -10 else { return nil }
        return [top]
    }

    // MARK: - Comfort + windows

    /// Comfort band in °C. Brachycephalic dogs lose the upper end (overheating
    /// risk); seniors and arthritic dogs lose the lower end (joint pain in cold).
    /// Pulled inline because the rule set is small and visible scoring is more
    /// useful than a pluggable strategy here.
    private static func comfortBand(for dog: Dog) -> ClosedRange<Double> {
        var low = 4.0
        var high = 22.0
        if dog.isBrachycephalic { high = 18 }
        if dog.hasArthritis     { low = 8 }
        if dog.hasHipDysplasia  { low = max(low, 7) }
        // Senior dogs (≥8 years) get tighter bounds on both ends.
        let years = Calendar.current.dateComponents([.year], from: dog.dateOfBirth, to: .now).year ?? 0
        if years >= 8 {
            low = max(low, 6)
            high = min(high, 20)
        }
        return low...high
    }

    private static func isInsideEnabledWindow(
        hour: HourlySnapshot,
        for dog: Dog,
        calendar: Calendar
    ) -> Bool {
        let h = calendar.component(.hour, from: hour.time)
        let enabled = (dog.walkWindows ?? []).filter(\.enabled)
        // If the user hasn't configured any windows yet, treat the whole sensible
        // span (5am-10pm) as in-bounds so the recommendation isn't gated on setup.
        if enabled.isEmpty { return (5...22).contains(h) }
        return enabled.contains { window in
            let (start, end) = hourRange(for: window.slot)
            return Double(h) >= start && Double(h) < end
        }
    }

    private static func hourRange(for slot: WalkSlot) -> (Double, Double) {
        switch slot {
        case .earlyMorning: return (5, 9)
        case .lunch:        return (11, 14)
        case .afternoon:    return (14, 18)
        case .evening:      return (18, 22)
        }
    }

    // MARK: - Copy

    private static func headline(
        start: Date,
        end: Date,
        durationHours: Int,
        category: WeatherCategory,
        temperatureC: Double,
        now: Date,
        calendar: Calendar
    ) -> String {
        let weather = weatherFragment(for: category)
        let temp = "\(Int(temperatureC.rounded()))°"
        let nowHour = calendar.component(.hour, from: now)
        let startHour = calendar.component(.hour, from: start)
        let endHour = calendar.component(.hour, from: end)
        let startsNow = startHour <= nowHour

        if durationHours >= 2 {
            // Multi-hour window — name the range so "the best window today"
            // actually reads as a window, not a single time.
            if startsNow {
                return "Best now until \(clockLabel(hour: endHour)). \(weather), \(temp)."
            }
            return "Best \(clockLabel(hour: startHour)) to \(clockLabel(hour: endHour)). \(weather), \(temp)."
        }
        // Single-hour fallback — rare; only when no contiguous run scored well.
        if startsNow {
            return "Best in this hour. \(weather), \(temp)."
        }
        return "Best around \(clockLabel(hour: startHour)). \(weather), \(temp)."
    }

    /// "1pm" / "10am" / "12pm". Used for the headline range so the user sees
    /// "Best 1pm to 3pm" rather than "from 13:00 to 15:00".
    static func clockLabel(hour: Int) -> String {
        switch hour {
        case 0: return "12am"
        case 12: return "12pm"
        case 1...11: return "\(hour)am"
        default: return "\(hour - 12)pm"
        }
    }

    private static func detail(for hour: HourlySnapshot, dog: Dog) -> String {
        switch hour.category {
        case .clear:        return "Clear sky. Easy on \(dog.name)."
        case .partlyCloudy: return "Bit of sun, bit of cloud."
        case .cloudy:       return "Overcast but dry."
        case .fog:          return "Foggy. Keep \(dog.name) close."
        case .drizzle:      return "Light drizzle. A short one is fine."
        case .rain:         return "Wet underfoot. Towel on standby."
        case .snow:         return "Snow about. Watch \(dog.name)'s paws."
        case .thunder:      return "Storms forecast. Indoors is fair."
        }
    }

    private static func weatherFragment(for category: WeatherCategory) -> String {
        switch category {
        case .clear:        return "Sunny"
        case .partlyCloudy: return "Bright"
        case .cloudy:       return "Cloudy"
        case .fog:          return "Foggy"
        case .drizzle:      return "Drizzly"
        case .rain:         return "Wet"
        case .snow:         return "Snowy"
        case .thunder:      return "Stormy"
        }
    }

}

extension Calendar {
    /// Top-of-the-current-hour. Used as the recommendation cutoff so we don't
    /// suggest a hour that has already begun and mostly elapsed.
    func startOfHour(for date: Date) -> Date {
        let comps = dateComponents([.year, .month, .day, .hour], from: date)
        return self.date(from: comps) ?? date
    }
}
