import Foundation
import UserNotifications

/// Thin iOS-facing wrapper. Decides what to schedule via `NotificationDecisions`,
/// then registers the actual `UNNotificationRequest`s. All `trot.*` identifiers
/// are owned by this service.
@MainActor
enum NotificationService {
    private static let nudgeID = "trot.nudge"
    private static let recapID = "trot.recap"
    private static func milestoneID(_ count: Int) -> String { "trot.milestone.\(count)" }

    /// Asks for permission. Idempotent — safe to call repeatedly.
    /// Returns true if the user has granted alerts permission.
    @discardableResult
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Cancels all Trot-owned pending notifications and re-schedules based on `dog`'s
    /// current state. Cheap to call frequently.
    static func reschedule(for dog: Dog, now: Date = .now, calendar: Calendar = .current) async {
        let center = UNUserNotificationCenter.current()

        await cancelAllTrotPending(center: center)

        await scheduleNudgeIfNeeded(for: dog, now: now, calendar: calendar, center: center)
        await scheduleMilestoneIfNeeded(for: dog, now: now, calendar: calendar, center: center)
        await scheduleRecap(for: dog, now: now, calendar: calendar, center: center)
    }

    /// Cancels all Trot-owned pending notifications. Used when the last active dog is archived.
    static func cancelAll() async {
        await cancelAllTrotPending(center: UNUserNotificationCenter.current())
    }

    // MARK: - Internals

    private static func cancelAllTrotPending(center: UNUserNotificationCenter) async {
        let pending = await center.pendingNotificationRequests()
        let trotIDs = pending.map(\.identifier).filter { $0.hasPrefix("trot.") }
        center.removePendingNotificationRequests(withIdentifiers: trotIDs)
    }

    private static func scheduleNudgeIfNeeded(
        for dog: Dog,
        now: Date,
        calendar: Calendar,
        center: UNUserNotificationCenter
    ) async {
        let minutesToday = (dog.walks ?? [])
            .filter { calendar.isDate($0.startedAt, inSameDayAs: now) }
            .reduce(0) { $0 + $1.durationMinutes }

        guard let fireAt = NotificationDecisions.nudgeTime(
            minutesToday: minutesToday,
            targetMinutes: dog.dailyTargetMinutes,
            now: now,
            calendar: calendar
        ) else { return }

        let content = UNMutableNotificationContent()
        content.title = dog.name
        content.body = NotificationDecisions.nudgeBody(
            dogName: dog.name,
            minutesToday: minutesToday,
            targetMinutes: dog.dailyTargetMinutes
        )
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireAt),
            repeats: false
        )

        let request = UNNotificationRequest(identifier: nudgeID, content: content, trigger: trigger)
        try? await center.add(request)
    }

    private static func scheduleMilestoneIfNeeded(
        for dog: Dog,
        now: Date,
        calendar: Calendar,
        center: UNUserNotificationCenter
    ) async {
        let streak = StreakService.currentStreak(for: dog, today: now, calendar: calendar)
        guard let (count, fireAt) = NotificationDecisions.milestoneFireTime(
            currentStreak: streak,
            now: now,
            calendar: calendar
        ) else { return }

        let content = UNMutableNotificationContent()
        content.title = dog.name
        content.body = NotificationDecisions.milestoneBody(streak: count, dogName: dog.name)
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireAt),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: milestoneID(count),
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    private static func scheduleRecap(
        for dog: Dog,
        now: Date,
        calendar: Calendar,
        center: UNUserNotificationCenter
    ) async {
        guard let fireAt = NotificationDecisions.nextRecapTime(now: now, calendar: calendar)
        else { return }

        let content = UNMutableNotificationContent()
        content.title = "Sunday recap"
        content.body = "\(dog.name)'s week is ready."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireAt),
            repeats: false
        )

        let request = UNNotificationRequest(identifier: recapID, content: content, trigger: trigger)
        try? await center.add(request)
    }
}
