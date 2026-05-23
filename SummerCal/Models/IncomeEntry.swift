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
    var source: String
    var descriptionText: String
    var category: IncomeCategory
    var createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date,
        amount: Double,
        source: String,
        descriptionText: String = "",
        category: IncomeCategory = .other,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.amount = amount
        self.source = source
        self.descriptionText = descriptionText
        self.category = category
        self.createdAt = createdAt
    }
}
