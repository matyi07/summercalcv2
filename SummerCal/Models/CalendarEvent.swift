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
    var reminderMinutesBeforeList: String?
    var customReminderDate: Date?
    var workTypeId: UUID?
    var workTypeName: String?
    var workRateAmount: Double?
    var workPricingMode: String?
    var workCurrencyCode: String?
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
        notificationEnabled: Bool = true,
        reminderMinutesBefore: Int = 30,
        reminderMinutesBeforeList: String? = "30",
        customReminderDate: Date? = nil,
        workTypeId: UUID? = nil,
        workTypeName: String? = nil,
        workRateAmount: Double? = nil,
        workPricingMode: String? = nil,
        workCurrencyCode: String? = nil,
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
        self.reminderMinutesBeforeList = reminderMinutesBeforeList
        self.customReminderDate = customReminderDate
        self.workTypeId = workTypeId
        self.workTypeName = workTypeName
        self.workRateAmount = workRateAmount
        self.workPricingMode = workPricingMode
        self.workCurrencyCode = workCurrencyCode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func overlaps(_ interval: DateInterval) -> Bool {
        startDate < interval.end && endDate > interval.start
    }

    func reminderOffsets() -> [Int] {
        guard let reminderMinutesBeforeList else {
            return [reminderMinutesBefore]
        }

        let rawOffsets = reminderMinutesBeforeList
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return Array(Set(rawOffsets)).sorted()
    }

    func setReminderOffsets(_ offsets: [Int]) {
        let cleaned = Array(Set(offsets.filter { $0 >= 0 })).sorted()
        reminderMinutesBeforeList = cleaned.map(String.init).joined(separator: ",")
        reminderMinutesBefore = cleaned.first ?? 30
    }

    var isWorkEvent: Bool {
        category == "work"
    }
}
