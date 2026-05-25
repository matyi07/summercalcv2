import Foundation
import SwiftData

@Model
final class WorkType {
    @Attribute(.unique) var id: UUID
    var name: String
    var rateAmount: Double
    var pricingMode: String
    var currencyCode: String?
    var defaultStartDate: Date?
    var defaultEndDate: Date?
    var defaultStartHour: Int?
    var defaultStartMinute: Int?
    var defaultEndHour: Int?
    var defaultEndMinute: Int?
    var note: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        rateAmount: Double,
        pricingMode: String = "hourly",
        currencyCode: String? = nil,
        defaultStartDate: Date? = nil,
        defaultEndDate: Date? = nil,
        defaultStartHour: Int? = nil,
        defaultStartMinute: Int? = nil,
        defaultEndHour: Int? = nil,
        defaultEndMinute: Int? = nil,
        note: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.rateAmount = rateAmount
        self.pricingMode = pricingMode
        self.currencyCode = currencyCode
        self.defaultStartDate = defaultStartDate
        self.defaultEndDate = defaultEndDate
        self.defaultStartHour = defaultStartHour
        self.defaultStartMinute = defaultStartMinute
        self.defaultEndHour = defaultEndHour
        self.defaultEndMinute = defaultEndMinute
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var usesDailyPricing: Bool {
        pricingMode == "daily"
    }
}
