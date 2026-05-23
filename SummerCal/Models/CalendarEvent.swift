import Foundation
import SwiftData

@Model
final class CalendarEvent {
    @Attribute(.unique) var id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var location: String?
    var notes: String?
    var category: String?
    var isOutdoor: Bool
    var recurrenceRule: String?
    var notificationEnabled: Bool
    var reminderMinutesBefore: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        location: String? = nil,
        notes: String? = nil,
        category: String? = nil,
        isOutdoor: Bool = false,
        recurrenceRule: String? = nil,
        notificationEnabled: Bool = false,
        reminderMinutesBefore: Int = 30,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location
        self.notes = notes
        self.category = category
        self.isOutdoor = isOutdoor
        self.recurrenceRule = recurrenceRule
        self.notificationEnabled = notificationEnabled
        self.reminderMinutesBefore = reminderMinutesBefore
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func overlaps(_ interval: DateInterval) -> Bool {
        startDate < interval.end && endDate > interval.start
    }
}
