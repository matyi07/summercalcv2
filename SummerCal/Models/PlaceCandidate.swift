import Foundation
import SwiftData

@Model
final class PlaceCandidate {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: String?
    var address: String?
    var latitude: Double
    var longitude: Double
    var openNow: Bool?
    var rating: Double?
    var placeId: String?
    var distanceMeters: Double?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        category: String? = nil,
        address: String? = nil,
        latitude: Double,
        longitude: Double,
        openNow: Bool? = nil,
        rating: Double? = nil,
        placeId: String? = nil,
        distanceMeters: Double? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.openNow = openNow
        self.rating = rating
        self.placeId = placeId
        self.distanceMeters = distanceMeters
        self.createdAt = createdAt
    }
}
