import DesignSystem
import Foundation
import Observation
import UserNotifications

/// The one weekly local notification (DESIGN.md flow #3): scheduled and fired
/// entirely on-device, generic copy only — no journal content ever touches the
/// Lock Screen — and passive, so it never buzzes through a Focus. The fixed
/// identifier means re-scheduling always replaces the previous request; there is
/// never more than one.
enum WeeklyReviewReminder {
    static let identifier = "app.inward.weeklyReviewReminder"

    /// Applies the current preference. Returns false when notification
    /// permission is denied, so the Settings toggle can settle back to off.
    static func apply(enabled: Bool, weekday: Int, minutesOfDay: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()
        guard enabled else {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            return true
        }
        // Requested here, in context from the Settings row — never at launch.
        guard await (try? center.requestAuthorization(options: [.alert])) == true else {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = Copy.weeklyReviewTitle
        content.body = Copy.weeklyReminderBody
        content.interruptionLevel = .passive

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(
                dateMatching: fireComponents(weekday: weekday, minutesOfDay: minutesOfDay),
                repeats: true
            )
        )
        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }

    /// Pure mapping: weekday 1…7 (Sunday-first, as `Calendar` counts) and
    /// minutes since midnight → the repeating local fire time.
    static func fireComponents(weekday: Int, minutesOfDay: Int) -> DateComponents {
        var components = DateComponents()
        components.weekday = min(max(weekday, 1), 7)
        let clamped = min(max(minutesOfDay, 0), 23 * 60 + 59)
        components.hour = clamped / 60
        components.minute = clamped % 60
        return components
    }
}

/// Bridges a reminder tap to the review surface, mirroring `QuickCaptureSignal`:
/// the delegate bumps a token; RootView observes it and opens the weekly review.
@MainActor
@Observable
final class WeeklyReviewSignal {
    static let shared = WeeklyReviewSignal()

    private(set) var requestToken = 0

    func requestOpen() {
        requestToken += 1
    }
}

/// Notification-center delegate, installed once at app init. Only reacts to the
/// weekly reminder; while the app is frontmost the banner is suppressed — the
/// person is already here. Stateless, hence the unchecked Sendable.
final class WeeklyReviewReminderDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = WeeklyReviewReminderDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.notification.request.identifier == WeeklyReviewReminder.identifier else { return }
        await MainActor.run { WeeklyReviewSignal.shared.requestOpen() }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        []
    }
}
