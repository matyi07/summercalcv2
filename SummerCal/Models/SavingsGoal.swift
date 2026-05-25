import Foundation
import SwiftData

@Model
final class SavingsGoal {
    @Attribute(.unique) var id: UUID
    var name: String
    var targetAmount: Double
    var currencyCode: String?
    var iconName: String
    var note: String
    var archived: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        targetAmount: Double,
        currencyCode: String? = nil,
        iconName: String = "target",
        note: String = "",
        archived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.targetAmount = targetAmount
        self.currencyCode = currencyCode
        self.iconName = iconName
        self.note = note
        self.archived = archived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
