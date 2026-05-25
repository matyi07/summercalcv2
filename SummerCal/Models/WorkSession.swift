import Foundation
import SwiftData

@Model
final class WorkSession {
    @Attribute(.unique) var id: UUID
    var date: Date
    var startTime: Date
    var endTime: Date
    var hourlyRate: Double
    var totalEarned: Double
    var currencyCode: String?
    var pricingMode: String?
    var calendarEventId: UUID?
    var workTypeId: UUID?
    var workTypeName: String?
    var descriptionText: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date,
        startTime: Date,
        endTime: Date,
        hourlyRate: Double,
        totalEarned: Double = 0,
        currencyCode: String? = nil,
        pricingMode: String? = "hourly",
        calendarEventId: UUID? = nil,
        workTypeId: UUID? = nil,
        workTypeName: String? = nil,
        descriptionText: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.hourlyRate = hourlyRate
        self.totalEarned = totalEarned
        self.currencyCode = currencyCode
        self.pricingMode = pricingMode
        self.calendarEventId = calendarEventId
        self.workTypeId = workTypeId
        self.workTypeName = workTypeName
        self.descriptionText = descriptionText
        self.createdAt = createdAt
    }

    var usesDailyPricing: Bool {
        pricingMode == "daily"
    }
}
