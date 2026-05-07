import Foundation

/// Trot's voice on Home — a contextual one-line nudge written about (and
/// implicitly from) the dog. The point is to make the app feel like the dog
/// is part of the user's day rather than a passive log of past walks.
///
/// Two surfaces:
/// - `currentLine(for:)` — pure-function, deterministic, no network. The
///   templated fallback. Always available, always instant.
/// - `dailyLine(for:)` — async wrapper. Tries `LLMService.dailyLine` first
///   (cached 24h per dog/day); falls back silently to `currentLine` on miss
///   or failure.
///
/// Templated copy stays calm by design — when the LLM is available, the user
/// gets dog-voice (loud, specific). When it isn't, they get a respectful
/// fallback that still names the dog and the moment.
enum DogVoiceService {
    /// LLM-first daily line for Home. Cached 24h per dog/day inside
    /// `LLMService`; this method just sequences "try LLM, otherwise template".
    /// Safe to call from a SwiftUI `.task` modifier — never throws, never
    /// blocks UI for more than 8s, never returns empty.
    static func dailyLine(
        for dog: Dog,
        now: Date = .now,
        calendar: Calendar = .current
    ) async -> String {
        if let llm = await LLMService.dailyLine(for: dog, now: now, calendar: calendar) {
            return llm
        }
        return currentLine(for: dog, now: now, calendar: calendar)
    }

    static func currentLine(
        for dog: Dog,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        let name = dog.name.isEmpty ? "Your dog" : dog.name
        let target = max(0, dog.dailyTargetMinutes)
        let walks = walksToday(for: dog, now: now, calendar: calendar)
        let minutes = walks.reduce(0) { $0 + $1.durationMinutes }
        let percent: Double = target > 0 ? Double(minutes) / Double(target) : 0
        let hour = calendar.component(.hour, from: now)
        let slot = SlotMap.current(forHour: hour)
        let enabled = enabledSlots(for: dog)

        // Precedence top → bottom. First match wins.

        // 1. Target met — calm praise.
        if percent >= 1.0 {
            return walks.count == 1
                ? "\(name) sorted that in one. Good walk."
                : "\(name)'s done for the day. Good work."
        }

        // 2. Late night with no walks — accept the day, don't nag.
        if hour >= 22 && minutes == 0 {
            return "\(name)'s settling. Tomorrow's a fresh start."
        }

        // 3. Some walks done, under target — encouragement scaled by progress.
        if minutes > 0 {
            if percent >= 0.5 {
                return "\(name)'s had \(minutes) minutes today. A short top-up rounds it off."
            }
            return "\(name)'s had \(minutes) minutes so far. Room for more."
        }

        // 4. No walks yet, currently inside an enabled window — direct nudge.
        if let slot, enabled.contains(slot) {
            return "\(name)'s \(SlotMap.spoken(slot)) window is open. \(SlotMap.openNudge(slot))"
        }

        // 5. No walks yet, a future enabled window today — set anticipation.
        if let next = nextEnabledWindow(currentHour: hour, enabled: enabled) {
            return "\(name)'s \(SlotMap.spoken(next)) window opens at \(SlotMap.startSpoken(next))."
        }

        // 6. No walks yet, no useful windows — part-of-day fallback.
        switch slot {
        case .earlyMorning:
            return "\(name) hasn't been out yet. A morning walk's a gentle start."
        case .lunch:
            return "\(name)'s been quiet all morning. Lunchtime walks count."
        case .afternoon:
            return "\(name)'s still waiting for today's walk."
        case .evening:
            return "\(name) hasn't been out today. Evening's the time."
        case nil:
            return "\(name) hasn't been out yet."
        }
    }

    // MARK: - Helpers

    private static func walksToday(for dog: Dog, now: Date, calendar: Calendar) -> [Walk] {
        (dog.walks ?? []).filter { calendar.isDate($0.startedAt, inSameDayAs: now) }
    }

    private static func enabledSlots(for dog: Dog) -> Set<WalkSlot> {
        Set((dog.walkWindows ?? []).filter(\.enabled).map(\.slot))
    }

    private static func nextEnabledWindow(
        currentHour: Int,
        enabled: Set<WalkSlot>
    ) -> WalkSlot? {
        let order: [WalkSlot] = [.earlyMorning, .lunch, .afternoon, .evening]
        return order.first { slot in
            enabled.contains(slot) && SlotMap.startHour(slot) > currentHour
        }
    }
}

/// Hour-bucketing + spoken-form helpers for `WalkSlot`. Lives next to the
/// service rather than as a public extension because the wording is voice-specific
/// (the spec's slots use 5-9, 11-2, 2-6, 6-10; the spoken forms are
/// Trot's voice, not a model concern).
private enum SlotMap {
    static func current(forHour hour: Int) -> WalkSlot? {
        switch hour {
        case 5..<9: return .earlyMorning
        case 11..<14: return .lunch
        case 14..<18: return .afternoon
        case 18..<22: return .evening
        default: return nil
        }
    }

    static func startHour(_ slot: WalkSlot) -> Int {
        switch slot {
        case .earlyMorning: return 5
        case .lunch: return 11
        case .afternoon: return 14
        case .evening: return 18
        }
    }

    static func spoken(_ slot: WalkSlot) -> String {
        switch slot {
        case .earlyMorning: return "morning"
        case .lunch: return "lunchtime"
        case .afternoon: return "afternoon"
        case .evening: return "evening"
        }
    }

    static func startSpoken(_ slot: WalkSlot) -> String {
        switch slot {
        case .earlyMorning: return "5"
        case .lunch: return "11"
        case .afternoon: return "2pm"
        case .evening: return "6pm"
        }
    }

    static func openNudge(_ slot: WalkSlot) -> String {
        switch slot {
        case .earlyMorning: return "Quiet so far."
        case .lunch: return "A short loop fits."
        case .afternoon: return "Good time for a longer one."
        case .evening: return "Still light enough."
        }
    }
}
