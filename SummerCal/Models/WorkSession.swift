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
        self.descriptionText = descriptionText
        self.createdAt = createdAt
    }

    var usesDailyPricing: Bool {
        pricingMode == "daily"
    }
}
