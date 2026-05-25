import Foundation
import SwiftData
import UserNotifications

final class NotificationBootstrapService {
    private let notificationService: NotificationService
    private let smartNotificationService: SmartNotificationService

    init(
        notificationService: NotificationService = .shared,
        smartNotificationService: SmartNotificationService = SmartNotificationService()
    ) {
        self.notificationService = notificationService
        self.smartNotificationService = smartNotificationService
    }

    func refresh(modelContext: ModelContext) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            break
        case .notDetermined:
            guard await notificationService.requestPermission() else { return }
        case .denied:
            return
        @unknown default:
            return
        }

        await refreshEventReminders(modelContext: modelContext)
        await smartNotificationService.runDailyPipeline(for: Date(), modelContext: modelContext)
    }

    private func refreshEventReminders(modelContext: ModelContext) async {
        let now = Date()
        let horizon = Calendar.current.date(byAdding: .day, value: 14, to: now) ?? now.addingTimeInterval(14 * 24 * 3600)

        let descriptor = FetchDescriptor<CalendarEvent>(
            predicate: #Predicate { event in
                event.startDate >= now && event.startDate < horizon
            },
            sortBy: [SortDescriptor(\.startDate)]
        )
        let events = (try? modelContext.fetch(descriptor)) ?? []

        for event in events {
            await notificationService.cancelAll(forEventId: event.id)
            guard event.notificationEnabled else { continue }
            _ = await notificationService.scheduleEventReminder(
                event: event,
                minutesBefore: event.reminderMinutesBefore,
                notes: nil
            )
        }
    }
}
