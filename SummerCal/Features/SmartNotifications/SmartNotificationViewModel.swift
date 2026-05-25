import SwiftUI
import SwiftData

@Observable
final class SmartNotificationViewModel {
    var rules: [SmartNotificationRule] = []
    var notificationLogs: [NotificationLog] = []
    var userSettings: UserSettings?
    var isScheduling = false
    var scheduleError: String?

    func loadAll(modelContext: ModelContext) {
        let ruleDescriptor = FetchDescriptor<SmartNotificationRule>(
            sortBy: [SortDescriptor(\.preferredHour)]
        )
        rules = (try? modelContext.fetch(ruleDescriptor)) ?? []

        ensureAllKindsPresent(modelContext: modelContext)

        let logDescriptor = FetchDescriptor<NotificationLog>(
            sortBy: [SortDescriptor(\.scheduledFor, order: .reverse)]
        )
        var logs = (try? modelContext.fetch(logDescriptor)) ?? []
        if logs.count > 50 {
            logs = Array(logs.prefix(50))
        }
        notificationLogs = logs

        userSettings = UserSettings.current(in: modelContext)
    }

    private func ensureAllKindsPresent(modelContext: ModelContext) {
        for kind in SmartNotificationKind.allCases {
            if !rules.contains(where: { $0.kind == kind }) {
                let rule = SmartNotificationRule(kind: kind)
                modelContext.insert(rule)
                try? modelContext.save()
                rules.append(rule)
            }
        }
    }

    func toggleRule(_ rule: SmartNotificationRule, modelContext: ModelContext) {
        rule.isEnabled.toggle()
        rule.updatedAt = Date()
        try? modelContext.save()
    }

    func updateQuietHours(start: Int, end: Int, modelContext: ModelContext) {
        guard let settings = userSettings else {
            userSettings = UserSettings.current(in: modelContext)
            return
        }
        settings.quietHoursStart = start
        settings.quietHoursEnd = end
        settings.updatedAt = Date()
        try? modelContext.save()

        for rule in rules {
            rule.quietHoursStart = start
            rule.quietHoursEnd = end
            rule.updatedAt = Date()
        }
        try? modelContext.save()
    }

    func updateFreeDayThreshold(_ hours: Int, modelContext: ModelContext) {
        guard let settings = userSettings else {
            userSettings = UserSettings.current(in: modelContext)
            return
        }
        settings.freeDayThresholdHours = Double(hours)
        settings.updatedAt = Date()
        try? modelContext.save()
    }

    func updateFreeDayCheck(hour: Int, minute: Int, modelContext: ModelContext) {
        guard let settings = userSettings else {
            userSettings = UserSettings.current(in: modelContext)
            return
        }
        settings.freeDayCheckHour = hour
        settings.freeDayCheckMinute = minute
        settings.updatedAt = Date()
        try? modelContext.save()
    }

    func updateMaxPerDay(_ max: Int, modelContext: ModelContext) {
        guard let settings = userSettings else {
            userSettings = UserSettings.current(in: modelContext)
            return
        }
        settings.maxSmartNotificationsPerDay = max
        settings.updatedAt = Date()
        try? modelContext.save()

        for rule in rules {
            rule.maxPerDay = max
            rule.updatedAt = Date()
        }
        try? modelContext.save()
    }

    func updateWeatherAlerts(_ enabled: Bool, modelContext: ModelContext) {
        guard let settings = userSettings else {
            userSettings = UserSettings.current(in: modelContext)
            return
        }
        settings.weatherAlertsEnabled = enabled
        settings.updatedAt = Date()
        try? modelContext.save()

        if let weatherRule = rules.first(where: { $0.kind == .weatherAlert }) {
            weatherRule.isEnabled = enabled
            weatherRule.updatedAt = Date()
            try? modelContext.save()
        }
    }

    func updateDailyWeatherSummary(_ enabled: Bool, modelContext: ModelContext) {
        guard let settings = userSettings else {
            userSettings = UserSettings.current(in: modelContext)
            return
        }
        settings.dailyWeatherSummaryEnabled = enabled
        settings.updatedAt = Date()
        try? modelContext.save()

        if let weatherRule = rules.first(where: { $0.kind == .weatherSummary }) {
            weatherRule.isEnabled = enabled
            weatherRule.updatedAt = Date()
            try? modelContext.save()
        }
    }

    func updateWeatherAlertThreshold(_ threshold: Double, modelContext: ModelContext) {
        guard let settings = userSettings else {
            userSettings = UserSettings.current(in: modelContext)
            return
        }
        settings.rainThreshold = threshold
        settings.updatedAt = Date()
        try? modelContext.save()
    }

    func resetToDefaults(modelContext: ModelContext) {
        guard let settings = userSettings else { return }
        settings.freeDayThresholdHours = 4
        settings.freeDayCheckHour = 9
        settings.freeDayCheckMinute = 0
        settings.rainThreshold = 0.5
        settings.dailyWeatherSummaryEnabled = true
        settings.weatherAlertsEnabled = true
        settings.quietHoursStart = 22
        settings.quietHoursEnd = 8
        settings.maxSmartNotificationsPerDay = 2
        settings.updatedAt = Date()

        for rule in rules {
            rule.isEnabled = true
            rule.preferredHour = 9
            rule.preferredMinute = 0
            rule.quietHoursStart = 22
            rule.quietHoursEnd = 8
            rule.maxPerDay = 2
            rule.updatedAt = Date()
        }
        try? modelContext.save()
        loadAll(modelContext: modelContext)
    }

    func triggerSchedulingPipeline(modelContext: ModelContext) async {
        isScheduling = true
        scheduleError = nil

        do {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            let permitted = await NotificationService.shared.requestPermission()
            guard permitted else {
                scheduleError = "Notifications are disabled. Enable them in iOS Settings to receive reminders."
                isScheduling = false
                loadAll(modelContext: modelContext)
                return
            }
            await NotificationBootstrapService().refresh(modelContext: modelContext)
        } catch {
            scheduleError = error.localizedDescription
        }

        isScheduling = false
        loadAll(modelContext: modelContext)
    }

    func clearNotificationLogs(modelContext: ModelContext) {
        for log in notificationLogs {
            modelContext.delete(log)
        }
        try? modelContext.save()
        loadAll(modelContext: modelContext)
    }
}
