import Foundation
import SwiftData

@Model
final class EventReminder {
    @Attribute(.unique) var id: UUID
    var eventId: UUID
    var reminderDate: Date
    var isCompleted: Bool
    var isSnoozed: Bool
    var snoozedUntil: Date?
    var notificationId: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        eventId: UUID,
        reminderDate: Date,
        isCompleted: Bool = false,
        isSnoozed: Bool = false,
        snoozedUntil: Date? = nil,
        notificationId: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.eventId = eventId
        self.reminderDate = reminderDate
        self.isCompleted = isCompleted
        self.isSnoozed = isSnoozed
        self.snoozedUntil = snoozedUntil
        self.notificationId = notificationId
        self.createdAt = createdAt
    }
}
