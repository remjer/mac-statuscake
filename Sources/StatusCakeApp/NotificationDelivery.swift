import Foundation
import UserNotifications
import StatusCakeCore

/// `UNUserNotificationCenter` requires a real app bundle -- a
/// `CFBundleIdentifier` from Info.plist -- to exist at all. Calling it from
/// an unbundled executable (which is what `swift run StatusCakeApp` still is
/// before phase 5 packages this as a proper .app) does not fail gracefully:
/// it crashes with "bundleProxyForCurrentProcess is nil". Every call site is
/// gated behind `isSupported` so that, until then, delivery is a deliberate
/// no-op rather than a crash -- the decision logic upstream (`statusMap`,
/// `diffTransitions`, `notificationFor`) runs and is tested regardless.
enum NotificationDelivery {
    private static var isSupported: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    static func requestAuthorization() {
        guard isSupported else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func setDelegate(_ delegate: UNUserNotificationCenterDelegate) {
        guard isSupported else { return }
        UNUserNotificationCenter.current().delegate = delegate
    }

    static func deliver(_ notification: StatusNotification) {
        guard isSupported else { return }
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        if notification.urgent { content.sound = .default }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
