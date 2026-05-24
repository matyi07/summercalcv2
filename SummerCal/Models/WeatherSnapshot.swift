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
    var humidity: Double?
    var feelsLikeCelsius: Double?
    var uvIndex: Int?
    var visibility: Double?
    var pressure: Double?
    var highTemp: Double?
    var lowTemp: Double?
    var sunrise: Date?
    var sunset: Date?
    var cloudCover: Double?
    var dewPointCelsius: Double?
    var airQualityIndex: Int?

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
        summary: String,
        humidity: Double? = nil,
        feelsLikeCelsius: Double? = nil,
        uvIndex: Int? = nil,
        visibility: Double? = nil,
        pressure: Double? = nil,
        highTemp: Double? = nil,
        lowTemp: Double? = nil,
        sunrise: Date? = nil,
        sunset: Date? = nil,
        cloudCover: Double? = nil,
        dewPointCelsius: Double? = nil,
        airQualityIndex: Int? = nil
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
        self.humidity = humidity
        self.feelsLikeCelsius = feelsLikeCelsius
        self.uvIndex = uvIndex
        self.visibility = visibility
        self.pressure = pressure
        self.highTemp = highTemp
        self.lowTemp = lowTemp
        self.sunrise = sunrise
        self.sunset = sunset
        self.cloudCover = cloudCover
        self.dewPointCelsius = dewPointCelsius
        self.airQualityIndex = airQualityIndex
    }
}
