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
                let todayWeather = fetchTodaysWeather(context: modelContext)
                let body = weatherService?.generateWeatherSummary(weather: todayWeather) ?? generateLocalWeatherSummary(from: todayWeather)
                await scheduleAndLog(kind: .weatherSummary, title: title, body: body, date: date, rule: rule, context: modelContext)
            case .weatherAlert:
                let todayWeather = fetchTodaysWeather(context: modelContext)
                await scheduleWeatherAlertsIfNeeded(weather: todayWeather, settings: settings, date: date, rule: rule, context: modelContext)
            case .eventPrep:
                break
            case .moneyReminder:
                if (settings.monthlyIncomeGoal ?? 0) > 0 {
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

    // MARK: - Weather helpers

    private func fetchTodaysWeather(context: ModelContext) -> WeatherSnapshot? {
        let now = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let descriptor = FetchDescriptor<WeatherSnapshot>(
            predicate: #Predicate { snapshot in
                snapshot.forecastDate >= startOfDay && snapshot.forecastDate < endOfDay
            },
            sortBy: [SortDescriptor(\.fetchedAt, order: .reverse)]
        )
        var results = (try? context.fetch(descriptor)) ?? []
        if results.isEmpty {
            let allDescriptor = FetchDescriptor<WeatherSnapshot>(
                sortBy: [SortDescriptor(\.fetchedAt, order: .reverse)]
            )
            results = (try? context.fetch(allDescriptor)) ?? []
        }
        return results.first
    }

    private func generateLocalWeatherSummary(from snapshot: WeatherSnapshot?) -> String {
        guard let w = snapshot else { return "Check the weather tab for today's forecast." }
        var parts = ["\(w.condition), \(String(format: "%.0f", w.temperatureCelsius))°C"]
        if let feels = w.feelsLikeCelsius {
            parts.append("feels like \(String(format: "%.0f", feels))°C")
        }
        if w.precipitationChance > 0.3 {
            parts.append("\(Int(w.precipitationChance * 100))% rain")
        }
        if let wind = w.windSpeedKph, wind > 15 {
            parts.append("wind \(String(format: "%.0f", wind)) km/h")
        }
        if let uv = w.uvIndex, uv >= 6 {
            parts.append("UV Index \(uv)")
        }
        return parts.joined(separator: ", ")
    }

    private func scheduleWeatherAlertsIfNeeded(
        weather: WeatherSnapshot?,
        settings: UserSettings,
        date: Date,
        rule: SmartNotificationRule,
        context: ModelContext
    ) async {
        guard let w = weather else { return }
        var alerts: [String] = []

        if settings.weatherAlertsEnabled {
            if w.precipitationChance >= settings.rainThreshold {
                alerts.append("Rain alert: \(Int(w.precipitationChance * 100))% chance today")
            }
            if w.temperatureCelsius >= settings.heatThresholdCelsius {
                alerts.append("Heat alert: \(String(format: "%.0f", w.temperatureCelsius))°C exceeds \(Int(settings.heatThresholdCelsius))°C")
            }
            if w.temperatureCelsius <= settings.coldThresholdCelsius {
                alerts.append("Cold alert: \(String(format: "%.0f", w.temperatureCelsius))°C is below \(Int(settings.coldThresholdCelsius))°C")
            }
        }

        for alert in alerts {
            await scheduleAndLog(
                kind: .weatherAlert,
                title: "Weather Alert",
                body: alert,
                date: date,
                rule: rule,
                context: context
            )
        }
    }

    // MARK: - Event notifications

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
        let scheduleDate = nextScheduledDate(for: rule, on: date)

        let scheduled = await notificationService.scheduleSmartNotification(
            id: notificationId,
            title: title,
            body: body,
            date: scheduleDate,
            categoryIdentifier: kind == .freeDay ? "FREE_DAY" : nil
        )
        guard scheduled else { return }

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

    private func nextScheduledDate(for rule: SmartNotificationRule, on date: Date) -> Date {
        let calendar = Calendar.current
        let preferred = calendar.date(
            bySettingHour: rule.preferredHour,
            minute: rule.preferredMinute,
            second: 0,
            of: date
        ) ?? date
        let minimumFutureDate = Date().addingTimeInterval(60)

        if preferred > minimumFutureDate {
            return preferred
        }

        if calendar.isDate(date, inSameDayAs: Date()) {
            return minimumFutureDate
        }

        return calendar.date(byAdding: .day, value: 1, to: preferred) ?? minimumFutureDate
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
