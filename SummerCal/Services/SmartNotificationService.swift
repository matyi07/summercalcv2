import Foundation
import SwiftData

final class SmartNotificationService {
    private let notificationService: NotificationService
    private let freeDayService: FreeDayDetectionService

    init(notificationService: NotificationService = .shared,
         freeDayService: FreeDayDetectionService = FreeDayDetectionService()) {
        self.notificationService = notificationService
        self.freeDayService = freeDayService
    }

    func runDailyPipeline(
        for date: Date,
        modelContext: ModelContext,
        weatherService: WeatherService? = nil,
        placesService: PlacesService? = nil
    ) async {
        let settings = UserSettings.current(in: modelContext)

        let eventDescriptor = FetchDescriptor<CalendarEvent>(sortBy: [SortDescriptor(\.startDate)])
        guard let allEvents = try? modelContext.fetch(eventDescriptor) else { return }

        let dayEvents = allEvents.filter { Calendar.current.isDate($0.startDate, inSameDayAs: date) }

        let ruleDescriptor = FetchDescriptor<SmartNotificationRule>()
        guard let rules = try? modelContext.fetch(ruleDescriptor) else { return }

        let todayLogs = (try? modelContext.fetch(FetchDescriptor<NotificationLog>()))?.filter {
            Calendar.current.isDate($0.scheduledFor, inSameDayAs: date)
        } ?? []

        for rule in rules where rule.isEnabled {
            if todayLogs.filter({ $0.kind == rule.kind }).count >= rule.maxPerDay { continue }
            if isInQuietHours(settings: settings) { continue }

            switch rule.kind {
            case .upcomingEvent:
                await scheduleUpcomingEventNotifications(events: dayEvents, notes: nil)
            case .freeDay:
                let freeWindows = freeDayService.freeWindows(for: date, events: dayEvents)
                if freeDayService.shouldNotifyFreeDay(freeWindows: freeWindows, thresholdHours: Double(settings.freeDayThresholdHours)) {
                    let title = "Free Day"
                    let body = freeDayService.notificationBody(for: freeWindows, weather: nil)
                    await scheduleAndLog(kind: .freeDay, title: title, body: body, date: date, rule: rule, context: modelContext)
                }
            case .freeAfternoon:
                let freeWindows = freeDayService.freeWindows(for: date, events: dayEvents)
                let afternoonFree = freeWindows.filter { win in
                    let hour = Calendar.current.component(.hour, from: win.start)
                    return hour >= 12
                }
                if freeDayService.shouldNotifyFreeDay(freeWindows: afternoonFree, thresholdHours: 2) {
                    await scheduleAndLog(
                        kind: .freeAfternoon,
                        title: "Free Afternoon",
                        body: "You have free time this afternoon. Good time for errands, gym, or a cafe work block.",
                        date: date,
                        rule: rule,
                        context: modelContext
                    )
                }
            case .weatherSummary:
                let title = "Weather Today"
                let body = weatherService?.generateWeatherSummary(weather: nil) ?? "Check the weather tab for today's forecast."
                await scheduleAndLog(kind: .weatherSummary, title: title, body: body, date: date, rule: rule, context: modelContext)
            case .weatherAlert:
                break
            case .eventPrep:
                break
            case .moneyReminder:
                if settings.monthlyIncomeGoal > 0 {
                    await scheduleAndLog(
                        kind: .moneyReminder,
                        title: "Money Check",
                        body: "How's your monthly goal going?",
                        date: date,
                        rule: rule,
                        context: modelContext
                    )
                }
            }
        }
    }

    private func scheduleUpcomingEventNotifications(events: [CalendarEvent], notes: [EventNote]?) async {
        for event in events {
            guard event.notificationEnabled else { continue }
            _ = await notificationService.scheduleEventReminder(
                event: event,
                minutesBefore: event.reminderMinutesBefore,
                notes: notes?.filter { $0.eventId == event.id }
            )
        }
    }

    private func scheduleAndLog(
        kind: SmartNotificationKind,
        title: String,
        body: String,
        date: Date,
        rule: SmartNotificationRule,
        context: ModelContext
    ) async {
        let notificationId = "smart_\(kind.rawValue)_\(UUID().uuidString)"
        let scheduleDate = Calendar.current.date(
            bySettingHour: rule.preferredHour,
            minute: rule.preferredMinute,
            second: 0,
            of: date
        ) ?? date

        await notificationService.scheduleSmartNotification(
            id: notificationId,
            title: title,
            body: body,
            date: scheduleDate,
            categoryIdentifier: kind == .freeDay ? "FREE_DAY" : nil
        )

        let log = NotificationLog(
            notificationId: notificationId,
            kind: kind,
            title: title,
            body: body,
            scheduledFor: scheduleDate
        )
        context.insert(log)
        try? context.save()
    }

    private func isInQuietHours(settings: UserSettings) -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        let quietStart = settings.quietHoursStart
        let quietEnd = settings.quietHoursEnd
        if quietStart < quietEnd {
            return hour >= quietStart && hour < quietEnd
        } else {
            return hour >= quietStart || hour < quietEnd
        }
    }
}
