import UserNotifications
import Foundation

private final class SummerCalNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = SummerCalNotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound, .badge]
    }
}

final class NotificationService {
    static let shared = NotificationService()

    private init() {
        UNUserNotificationCenter.current().delegate = SummerCalNotificationDelegate.shared
        registerCategories()
    }

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch { return false }
    }

    @discardableResult
    func scheduleEventReminder(event: CalendarEvent, minutesBefore: Int, notes: [EventNote]?) async -> String? {
        guard await ensureAuthorized() else { return nil }

        let notificationId = "event_reminder_\(event.id.uuidString)_\(minutesBefore)"
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.sound = .default

        let requestedTriggerDate = event.startDate.addingTimeInterval(-Double(minutesBefore * 60))
        let minimumFutureDate = Date().addingTimeInterval(5)
        let triggerDate: Date
        if requestedTriggerDate > minimumFutureDate {
            triggerDate = requestedTriggerDate
        } else if event.startDate > minimumFutureDate {
            triggerDate = minimumFutureDate
        } else {
            cancelNotification(id: notificationId)
            return nil
        }

        let effectiveMinutes = max(0, Int(event.startDate.timeIntervalSince(triggerDate) / 60))
        var body = effectiveMinutes == 0 ? "Starts now" : "Starts in \(effectiveMinutes) minutes"
        if let notes = notes, !notes.isEmpty {
            body += ". Notes: " + notes.prefix(2).map { $0.body }.joined(separator: ". ")
        }
        content.body = body
        content.userInfo = ["eventId": event.id.uuidString, "notificationType": "event_reminder"]
        content.categoryIdentifier = "EVENT_REMINDER"

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to schedule event notification \(notificationId): \(error.localizedDescription)")
            return nil
        }

        return notificationId
    }

    @discardableResult
    func scheduleEventReminder(event: CalendarEvent, triggerDate: Date, notes: [EventNote]?) async -> String? {
        guard await ensureAuthorized() else { return nil }

        guard triggerDate > Date().addingTimeInterval(5) else { return nil }

        let timestamp = Int(triggerDate.timeIntervalSince1970)
        let notificationId = "event_reminder_\(event.id.uuidString)_custom_\(timestamp)"
        let content = UNMutableNotificationContent()
        content.title = event.title
        content.sound = .default

        let eventFormatter = DateFormatter()
        eventFormatter.dateStyle = .medium
        eventFormatter.timeStyle = event.isAllDay ? .none : .short
        var body = "Reminder for \(eventFormatter.string(from: event.startDate))"
        if let notes = notes, !notes.isEmpty {
            body += ". Notes: " + notes.prefix(2).map { $0.body }.joined(separator: ". ")
        }
        content.body = body
        content.userInfo = ["eventId": event.id.uuidString, "notificationType": "event_reminder"]
        content.categoryIdentifier = "EVENT_REMINDER"

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: notificationId, content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
            return notificationId
        } catch {
            print("Failed to schedule event notification \(notificationId): \(error.localizedDescription)")
            return nil
        }
    }

    @discardableResult
    func scheduleAllEventReminders(event: CalendarEvent, notes: [EventNote]?) async -> [String] {
        guard event.notificationEnabled else { return [] }

        var scheduledIds: [String] = []
        for minutes in event.reminderOffsets() {
            if let id = await scheduleEventReminder(event: event, minutesBefore: minutes, notes: notes) {
                scheduledIds.append(id)
            }
        }

        if let customReminderDate = event.customReminderDate,
           let id = await scheduleEventReminder(event: event, triggerDate: customReminderDate, notes: notes) {
            scheduledIds.append(id)
        }

        return scheduledIds
    }

    @discardableResult
    func scheduleSmartNotification(id: String, title: String, body: String, date: Date, categoryIdentifier: String? = nil) async -> Bool {
        guard await ensureAuthorized() else { return false }
        guard date > Date().addingTimeInterval(5) else {
            cancelNotification(id: id)
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier ?? ""

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            print("Failed to schedule smart notification \(id): \(error.localizedDescription)")
            return false
        }
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

    private func ensureAuthorized() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return await requestPermission()
        case .denied:
            return false
        @unknown default:
            return false
        }
    }
}
