import Foundation
import SwiftData

enum ExpenseCategory: String, Codable, CaseIterable {
    case housing, utilities, food, transport, health, entertainment, shopping, subscription, travel, education, other

    var label: String {
        switch self {
        case .housing: return "Housing"
        case .utilities: return "Utilities"
        case .food: return "Food"
        case .transport: return "Transport"
        case .health: return "Health"
        case .entertainment: return "Entertainment"
        case .shopping: return "Shopping"
        case .subscription: return "Subscription"
        case .travel: return "Travel"
        case .education: return "Education"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .housing: return "house"
        case .utilities: return "bolt"
        case .food: return "fork.knife"
        case .transport: return "car"
        case .health: return "heart"
        case .entertainment: return "tv"
        case .shopping: return "bag"
        case .subscription: return "repeat"
        case .travel: return "airplane"
        case .education: return "book"
        case .other: return "ellipsis.circle"
        }
    }
}

@Model
final class ExpenseEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var amount: Double
    var currencyCode: String?
    var originalAmount: Double?
    var originalCurrencyCode: String?
    var exchangeRateToEntryCurrency: Double?
    var exchangeRateDate: String?
    var category: ExpenseCategory
    var paymentMethod: String
    var note: String
    var receiptImageData: Data?
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
        category: ExpenseCategory = .other,
        paymentMethod: String = "card",
        note: String = "",
        receiptImageData: Data? = nil,
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
        self.category = category
        self.paymentMethod = paymentMethod
        self.note = note
        self.receiptImageData = receiptImageData
        self.createdAt = createdAt
    }
}
