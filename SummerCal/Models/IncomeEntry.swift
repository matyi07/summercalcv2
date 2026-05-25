import Foundation
import SwiftData

enum IncomeCategory: String, Codable, CaseIterable {
    case salary
    case freelance
    case gig
    case other
}

@Model
final class IncomeEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var amount: Double
    var currencyCode: String?
    var originalAmount: Double?
    var originalCurrencyCode: String?
    var exchangeRateToEntryCurrency: Double?
    var exchangeRateDate: String?
    var source: String
    var descriptionText: String
    var category: IncomeCategory
    var createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date,
        amount: Double,
        currencyCode: String? = nil,
        originalAmount: Double? = nil,
        originalCurrencyCode: String? = nil,
        exchangeRateToEntryCurrency: Double? = nil,
        exchangeRateDate: String? = nil,
        source: String,
        descriptionText: String = "",
        category: IncomeCategory = .other,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.amount = amount
        self.currencyCode = currencyCode
        self.originalAmount = originalAmount
        self.originalCurrencyCode = originalCurrencyCode
        self.exchangeRateToEntryCurrency = exchangeRateToEntryCurrency
        self.exchangeRateDate = exchangeRateDate
        self.source = source
        self.descriptionText = descriptionText
        self.category = category
        self.createdAt = createdAt
    }
}
