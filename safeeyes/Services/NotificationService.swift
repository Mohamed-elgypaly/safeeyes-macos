import Foundation
import UserNotifications
import os

public final class NotificationService: NSObject, NotificationScheduling {
    public static let shared = NotificationService()

    public override init() {
        super.init()
    }

    public func requestAuthorization() async -> Bool {
        do {
            let center = UNUserNotificationCenter.current()
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            Log.notifications.info("Notification authorization granted: \(granted, privacy: .public)")
            return granted
        } catch {
            Log.notifications.error("Notification authorization request failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    public func scheduleBreakNotice(kind: BreakKind, leadSeconds: TimeInterval) {
        Log.notifications.info("Scheduling notification for \(kind.rawValue, privacy: .public) break in \(leadSeconds, privacy: .public)s")
    }

    public func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["safeeyes.prebreak"])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["safeeyes.prebreak"])
        Log.notifications.debug("Cancelled pre-break notifications")
    }
}
