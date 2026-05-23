import Foundation
import SwiftData

enum SmartNotificationKind: String, Codable, CaseIterable {
    case upcomingEvent
    case freeDay
    case freeAfternoon
    case weatherSummary
    case weatherAlert
    case eventPrep
    case moneyReminder

    var displayName: String {
        switch self {
        case .upcomingEvent: "Upcoming Events"
        case .freeDay: "Free Day"
        case .freeAfternoon: "Free Afternoon"
        case .weatherSummary: "Weather Summary"
        case .weatherAlert: "Weather Alerts"
        case .eventPrep: "Event Preparation"
        case .moneyReminder: "Money Reminders"
        }
    }

    var description: String {
        switch self {
        case .upcomingEvent: "Remind before events"
        case .freeDay: "Notify when day is free"
        case .freeAfternoon: "Notify when afternoon is free"
        case .weatherSummary: "Daily morning weather summary"
        case .weatherAlert: "Rain, heat, snow alerts"
        case .eventPrep: "Preparation suggestions before events"
        case .moneyReminder: "Monthly earnings goal tracking"
        }
    }
}

@Model
final class SmartNotificationRule {
    @Attribute(.unique) var id: UUID
    var kind: SmartNotificationKind
    var isEnabled: Bool
    var preferredHour: Int
    var preferredMinute: Int
    var quietHoursStart: Int
    var quietHoursEnd: Int
    var maxPerDay: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        kind: SmartNotificationKind,
        isEnabled: Bool = true,
        preferredHour: Int = 9,
        preferredMinute: Int = 0,
        quietHoursStart: Int = 22,
        quietHoursEnd: Int = 8,
        maxPerDay: Int = 2,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.isEnabled = isEnabled
        self.preferredHour = preferredHour
        self.preferredMinute = preferredMinute
        self.quietHoursStart = quietHoursStart
        self.quietHoursEnd = quietHoursEnd
        self.maxPerDay = maxPerDay
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
