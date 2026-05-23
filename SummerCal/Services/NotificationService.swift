import UserNotifications
import Foundation

final class NotificationService {
    static let shared = NotificationService()

    private init() { registerCategories() }

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch { return false }
    }

    func scheduleEventReminder(event: CalendarEvent, minutesBefore: Int, notes: [EventNote]?) async -> String {
        let notificationId = "event_reminder_\(event.id.uuidString)_\(minutesBefore)"
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.sound = .default

        var body = "Starts in \(minutesBefore) minutes"
        if let notes = notes, !notes.isEmpty {
            body += ". Notes: " + notes.prefix(2).map { $0.body }.joined(separator: ". ")
        }
        content.body = body
        content.userInfo = ["eventId": event.id.uuidString, "notificationType": "event_reminder"]
        content.categoryIdentifier = "EVENT_REMINDER"

        let triggerDate = event.startDate.addingTimeInterval(-Double(minutesBefore * 60))
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)

        return notificationId
    }

    func scheduleSmartNotification(id: String, title: String, body: String, date: Date, categoryIdentifier: String? = nil) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier ?? ""

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    func cancelNotification(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    func cancelAll(forEventId eventId: UUID) async {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let toCancel = pending.filter { request in
            if let eid = request.content.userInfo["eventId"] as? String {
                return eid == eventId.uuidString
            }
            return false
        }.map { $0.identifier }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: toCancel)
    }

    func getPendingNotifications() async -> [UNNotificationRequest] {
        await UNUserNotificationCenter.current().pendingNotificationRequests()
    }

    func removeAllPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    private func registerCategories() {
        let openEventAction = UNNotificationAction(identifier: "OPEN_EVENT", title: "Open Event", options: .foreground)
        let showNotesAction = UNNotificationAction(identifier: "SHOW_NOTES", title: "Show Notes", options: .foreground)
        let snoozeAction = UNNotificationAction(identifier: "SNOOZE_10MIN", title: "Snooze 10 min", options: [])
        let markPreparedAction = UNNotificationAction(identifier: "MARK_PREPARED", title: "Mark Prepared", options: [])
        let planAroundAction = UNNotificationAction(identifier: "PLAN_AROUND", title: "Plan Around It", options: .foreground)

        let eventCategory = UNNotificationCategory(
            identifier: "EVENT_REMINDER",
            actions: [openEventAction, showNotesAction, snoozeAction, markPreparedAction, planAroundAction],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        let viewAction = UNNotificationAction(identifier: "VIEW_FREE_DAY", title: "View Suggestions", options: .foreground)
        let freeDayCategory = UNNotificationCategory(
            identifier: "FREE_DAY",
            actions: [viewAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([eventCategory, freeDayCategory])
    }
}
