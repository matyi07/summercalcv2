import Foundation
import SwiftData

@Model
final class NotificationLog {
    @Attribute(.unique) var id: UUID
    var notificationId: String
    var kind: SmartNotificationKind
    var title: String
    var body: String
    var scheduledFor: Date
    var deliveredEstimate: Date?
    var relatedEventId: UUID?
    var relatedSuggestionId: UUID?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        notificationId: String,
        kind: SmartNotificationKind,
        title: String,
        body: String,
        scheduledFor: Date,
        deliveredEstimate: Date? = nil,
        relatedEventId: UUID? = nil,
        relatedSuggestionId: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.notificationId = notificationId
        self.kind = kind
        self.title = title
        self.body = body
        self.scheduledFor = scheduledFor
        self.deliveredEstimate = deliveredEstimate
        self.relatedEventId = relatedEventId
        self.relatedSuggestionId = relatedSuggestionId
        self.createdAt = createdAt
    }
}
