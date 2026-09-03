import Foundation
import UserNotifications

/// "Today's Rot is ready" — a local notification, opt-in, at a time the player
/// picks. No server, no push certificates, and it's the single cheapest D1
/// retention lever a daily game has.
enum Reminders {
    private static let id = "rotcheck.daily"
    private static let hourKey = "reminder.hour"
    private static let minuteKey = "reminder.minute"
    private static let enabledKey = "reminder.enabled"

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }

    static var time: (hour: Int, minute: Int) {
        let d = UserDefaults.standard
        return d.object(forKey: hourKey) == nil ? (18, 30) : (d.integer(forKey: hourKey), d.integer(forKey: minuteKey))
    }

    @discardableResult
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func enable(hour: Int, minute: Int) async -> Bool {
        guard await requestAuthorization() else { return false }
        let d = UserDefaults.standard
        d.set(hour, forKey: hourKey)
        d.set(minute, forKey: minuteKey)
        d.set(true, forKey: enabledKey)

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])

        let content = UNMutableNotificationContent()
        content.title = "Today's Rot is ready"
        content.body = "20 cards. One shot. Don't get cooked."
        content.sound = .default

        var when = DateComponents()
        when.hour = hour
        when.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        return true
    }

    static func disable() {
        UserDefaults.standard.set(false, forKey: enabledKey)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
