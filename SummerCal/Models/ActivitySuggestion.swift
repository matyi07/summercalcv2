import Foundation
import SwiftData

@Model
final class ActivitySuggestion {
    @Attribute(.unique) var id: UUID
    var date: Date
    var title: String
    var summary: String
    var category: String?
    var estimatedDurationMinutes: Int?
    var estimatedCostLevel: Int?
    var placeName: String?
    var placeId: String?
    var weatherReason: String?
    var aiProvider: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date,
        title: String,
        summary: String,
        category: String? = nil,
        estimatedDurationMinutes: Int? = nil,
        estimatedCostLevel: Int? = nil,
        placeName: String? = nil,
        placeId: String? = nil,
        weatherReason: String? = nil,
        aiProvider: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.summary = summary
        self.category = category
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.estimatedCostLevel = estimatedCostLevel
        self.placeName = placeName
        self.placeId = placeId
        self.weatherReason = weatherReason
        self.aiProvider = aiProvider
        self.createdAt = createdAt
    }
}
