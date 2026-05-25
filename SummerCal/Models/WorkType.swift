import Foundation
import SwiftData

@Model
final class WorkType {
    @Attribute(.unique) var id: UUID
    var name: String
    var rateAmount: Double
    var pricingMode: String
    var currencyCode: String?
    var note: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        rateAmount: Double,
        pricingMode: String = "hourly",
        currencyCode: String? = nil,
        note: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.rateAmount = rateAmount
        self.pricingMode = pricingMode
        self.currencyCode = currencyCode
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var usesDailyPricing: Bool {
        pricingMode == "daily"
    }
}
