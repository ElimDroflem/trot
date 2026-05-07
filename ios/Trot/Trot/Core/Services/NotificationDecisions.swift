import Foundation

/// Pure functions for "when should each Trot notification fire?"
/// No side effects, no UNUserNotificationCenter access — that lives in NotificationService.
/// Spec: see docs/spec.md "Notifications" + docs/decisions.md.
enum NotificationDecisions {
    /// Returns 19:00 today if a nudge should fire, else nil.
    /// Rules: not Sunday, before 19:00, progress <50% of target.
    static func nudgeTime(
        minutesToday: Int,
        targetMinutes: Int,
        now: Date,
        calendar: Calendar
    ) -> Date? {
        // Sunday suppression — Sunday recap takes precedence
        let weekday = calendar.component(.weekday, from: now)
        if weekday == 1 { return nil }

        guard let nineteen = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: now)
        else { return nil }

        if now >= nineteen { return nil }

        guard targetMinutes > 0 else { return nil }
        let halfTarget = Double(targetMinutes) / 2.0
        if Double(minutesToday) >= halfTarget { return nil }

        return nineteen
    }

    /// If `currentStreak` is 7, 14, or 30, returns the morning-after fire time at 09:00.
    static func milestoneFireTime(
        currentStreak: Int,
        now: Date,
        calendar: Calendar
    ) -> (count: Int, fireAt: Date)? {
        guard [7, 14, 30].contains(currentStreak) else { return nil }

        guard
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
            let nineAM = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)
        else { return nil }

        return (currentStreak, nineAM)
    }

    /// Returns the next Sunday at 19:00 from `now`.
    /// If today is Sunday and 19:00 hasn't passed, returns today 19:00.
    static func nextRecapTime(now: Date, calendar: Calendar) -> Date? {
        let weekday = calendar.component(.weekday, from: now)

        let daysUntilSunday: Int
        if weekday == 1 {
            // Today is Sunday
            guard let nineteenToday = calendar.date(
                bySettingHour: 19, minute: 0, second: 0, of: now
            ) else { return nil }
            daysUntilSunday = (now < nineteenToday) ? 0 : 7
        } else {
            daysUntilSunday = (1 - weekday + 7) % 7
        }

        guard
            let sunday = calendar.date(byAdding: .day, value: daysUntilSunday, to: now),
            let recap = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: sunday)
        else { return nil }

        return recap
    }

    /// Body copy for a streak milestone, per brand voice (no exclamation marks, dog-focused).
    static func milestoneBody(streak: Int, dogName: String) -> String {
        switch streak {
        case 7: return "A full week of walks. \(dogName)'s on it."
        case 14: return "14 days. \(dogName)'s longest streak so far."
        case 30: return "30 days. That's the kind of routine \(dogName) thrives on."
        default: return "\(streak.pluralised("day"))."
        }
    }

    /// Body copy for the under-target nudge.
    static func nudgeBody(dogName: String, minutesToday: Int, targetMinutes: Int) -> String {
        "\(dogName) has had \(minutesToday) minutes today. Target is \(targetMinutes)."
    }

    /// Daily 7:00 local "good morning" nudge — kicks the user toward today's
    /// best walk window. Returns the next 07:00 from `now` (today if it hasn't
    /// happened yet, otherwise tomorrow).
    static func morningWindowTime(now: Date, calendar: Calendar) -> Date? {
        guard let sevenToday = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now)
        else { return nil }
        if now < sevenToday { return sevenToday }
        return calendar.date(byAdding: .day, value: 1, to: sevenToday)
    }

    /// Body copy for the morning walk-window push. Stays calm and dog-focused.
    static func morningWindowBody(dogName: String) -> String {
        "Good morning. Open Trot for \(dogName)'s walk window today."
    }
}
