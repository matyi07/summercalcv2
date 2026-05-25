import Foundation
import SwiftData

@Model
final class SavingsEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var amount: Double
    var currencyCode: String?
    var originalAmount: Double?
    var originalCurrencyCode: String?
    var exchangeRateToEntryCurrency: Double?
    var exchangeRateDate: String?
    var goalId: UUID?
    var note: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        amount: Double,
        currencyCode: String? = nil,
        originalAmount: Double? = nil,
        originalCurrencyCode: String? = nil,
        exchangeRateToEntryCurrency: Double? = nil,
        exchangeRateDate: String? = nil,
        goalId: UUID? = nil,
        note: String = "",
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
        self.goalId = goalId
        self.note = note
        self.createdAt = createdAt
    }
}
