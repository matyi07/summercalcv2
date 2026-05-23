import Foundation
import SwiftData

@Model
final class WeatherSnapshot {
    @Attribute(.unique) var id: UUID
    var latitude: Double
    var longitude: Double
    var fetchedAt: Date
    var forecastDate: Date
    var condition: String
    var temperatureCelsius: Double
    var precipitationChance: Double
    var windSpeedKph: Double?
    var summary: String

    init(
        id: UUID = UUID(),
        latitude: Double,
        longitude: Double,
        fetchedAt: Date,
        forecastDate: Date,
        condition: String,
        temperatureCelsius: Double,
        precipitationChance: Double,
        windSpeedKph: Double? = nil,
        summary: String
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.fetchedAt = fetchedAt
        self.forecastDate = forecastDate
        self.condition = condition
        self.temperatureCelsius = temperatureCelsius
        self.precipitationChance = precipitationChance
        self.windSpeedKph = windSpeedKph
        self.summary = summary
    }
}
