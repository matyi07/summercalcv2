import Foundation
import SwiftData

@Model
final class UserSettings {
    @Attribute(.unique) var id: UUID
    var aiProviderKind: String
    var aiModelName: String
    var aiBaseURL: String?
    var aiMaxTokens: Int
    var freeDayThresholdHours: Double
    var freeDayCheckHour: Int
    var freeDayCheckMinute: Int
    var rainThreshold: Double
    var heatThresholdCelsius: Double
    var coldThresholdCelsius: Double
    var dailyWeatherSummaryEnabled: Bool
    var weatherAlertsEnabled: Bool
    var quietHoursStart: Int
    var quietHoursEnd: Int
    var maxSmartNotificationsPerDay: Int
    var nextDayFreePreviewEnabled: Bool
    var monthlyIncomeGoal: Double?
    var currencyCode: String
    var weatherKitJWT: String?
    var googlePlacesAPIKey: String?
    var selectedActivities: String?  // comma-separated, e.g. "indoor,outdoor,productive"
    var energyLevel: Double?
    var budgetPreference: String?
    var locationEnabled: Bool?
    var approximateLocation: Bool?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        aiProviderKind: String = "openAI",
        aiModelName: String = "gpt-4o",
        aiBaseURL: String? = nil,
        aiMaxTokens: Int = 1024,
        freeDayThresholdHours: Double = 4.0,
        freeDayCheckHour: Int = 9,
        freeDayCheckMinute: Int = 0,
        rainThreshold: Double = 0.5,
        heatThresholdCelsius: Double = 35,
        coldThresholdCelsius: Double = 0,
        dailyWeatherSummaryEnabled: Bool = true,
        weatherAlertsEnabled: Bool = true,
        quietHoursStart: Int = 22,
        quietHoursEnd: Int = 8,
        maxSmartNotificationsPerDay: Int = 2,
        nextDayFreePreviewEnabled: Bool = false,
        monthlyIncomeGoal: Double? = nil,
        currencyCode: String = "USD",
        weatherKitJWT: String? = nil,
        googlePlacesAPIKey: String? = nil,
        selectedActivities: String? = "indoor,outdoor,productive,social",
        energyLevel: Double? = 3,
        budgetPreference: String? = "medium",
        locationEnabled: Bool? = true,
        approximateLocation: Bool? = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.aiProviderKind = aiProviderKind
        self.aiModelName = aiModelName
        self.aiBaseURL = aiBaseURL
        self.aiMaxTokens = aiMaxTokens
        self.freeDayThresholdHours = freeDayThresholdHours
        self.freeDayCheckHour = freeDayCheckHour
        self.freeDayCheckMinute = freeDayCheckMinute
        self.rainThreshold = rainThreshold
        self.heatThresholdCelsius = heatThresholdCelsius
        self.coldThresholdCelsius = coldThresholdCelsius
        self.dailyWeatherSummaryEnabled = dailyWeatherSummaryEnabled
        self.weatherAlertsEnabled = weatherAlertsEnabled
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
        self.maxSmartNotificationsPerDay = maxSmartNotificationsPerDay
        self.nextDayFreePreviewEnabled = nextDayFreePreviewEnabled
        self.monthlyIncomeGoal = monthlyIncomeGoal
        self.currencyCode = currencyCode
        self.weatherKitJWT = weatherKitJWT
        self.googlePlacesAPIKey = googlePlacesAPIKey
        self.selectedActivities = selectedActivities
        self.energyLevel = energyLevel
        self.budgetPreference = budgetPreference
        self.locationEnabled = locationEnabled
        self.approximateLocation = approximateLocation
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func current(in context: ModelContext) -> UserSettings {
        let descriptor = FetchDescriptor<UserSettings>(sortBy: [SortDescriptor(\.createdAt)])
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let settings = UserSettings()
        context.insert(settings)
        try? context.save()
        return settings
    }
}
