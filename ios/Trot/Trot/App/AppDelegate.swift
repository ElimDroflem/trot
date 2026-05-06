import SwiftUI
import UserNotifications

/// AppDelegate exists for one job in v1: receiving notification taps and routing
/// them to SwiftUI via Foundation's `NotificationCenter`. Pure SwiftUI lifecycle
/// can't intercept `UNUserNotificationCenterDelegate` callbacks directly.
///
/// The `UN` delegate methods translate iOS notification events into Foundation
/// notifications that `RootView` listens for via `.onReceive`. This keeps AppState
/// untouched by `UN*` types — the SwiftUI side just sees an "event happened" signal.
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Foreground presentation — show the banner like a normal notification rather
    /// than swallowing it. Without this, notifications silently no-op when the
    /// user has the app open.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// User tapped a notification. Route by identifier.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        if identifier == "trot.recap" {
            NotificationCenter.default.post(name: .trotRecapTapped, object: nil)
        }
        // Future identifiers (nudge, milestone) can route here too.
        completionHandler()
    }
}

extension Notification.Name {
    /// Posted when the user taps the Sunday weekly-recap notification.
    /// `RootView` observes this to set `AppState.pendingRecapDogID` and present the sheet.
    static let trotRecapTapped = Notification.Name("dog.trot.notification.recapTapped")
}
