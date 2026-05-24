import Foundation
import CoreLocation
import SwiftData

final class WeatherService: ObservableObject {
    @Published var currentSnapshot: WeatherSnapshot?
    @Published var hourlyForecast: [WeatherSnapshot] = []
    @Published var dailyForecast: [WeatherSnapshot] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var lastSource: String = ""

    // MARK: - Legacy API (TodayView / ContentView compatibility)

    func fetchWeather(for coordinate: Coordinate) async {
        await MainActor.run { isLoading = true; error = nil }
        do {
            let snapshot = try await fetchCurrentWeather(coordinate: coordinate)
            await MainActor.run {
                self.currentSnapshot = snapshot
                self.lastSource = "OpenWeatherMap"
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func fetchCurrentWeather(coordinate: Coordinate) async throws -> WeatherSnapshot {
        let key = resolveAPIKey()
        let urlString = "https://api.openweathermap.org/data/2.5/weather?lat=\(coordinate.latitude)&lon=\(coordinate.longitude)&units=metric&appid=\(key)"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "WeatherService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid OWM URL"])
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "WeatherService", code: 500)
        }

        let main = json["main"] as? [String: Any]
        let temp = main?["temp"] as? Double ?? 0
        let humidity = main?["humidity"] as? Double
        let feelsLike = main?["feels_like"] as? Double
        let pressure = main?["pressure"] as? Double
        let tempMin = main?["temp_min"] as? Double
        let tempMax = main?["temp_max"] as? Double

        let wind = json["wind"] as? [String: Any]
        let windSpeedMs = wind?["speed"] as? Double
        let windSpeedKph = windSpeedMs.map { $0 * 3.6 }

        let weatherArr = json["weather"] as? [[String: Any]]
        let firstWeather = weatherArr?.first
        let conditionCode = firstWeather?["id"] as? Int ?? 800
        let conditionDesc = firstWeather?["description"] as? String ?? "clear sky"
        let conditionMain = firstWeather?["main"] as? String ?? "Clear"

        let clouds = json["clouds"] as? [String: Any]
        let cloudCover = clouds?["all"] as? Double

        let visibility = json["visibility"] as? Double

        let sys = json["sys"] as? [String: Any]
        let sunriseTimestamp = sys?["sunrise"] as? TimeInterval
        let sunsetTimestamp = sys?["sunset"] as? TimeInterval
        let sunrise = sunriseTimestamp.map { Date(timeIntervalSince1970: $0) }
        let sunset = sunsetTimestamp.map { Date(timeIntervalSince1970: $0) }

        let rain = json["rain"] as? [String: Any]
        let precipMm = rain?["1h"] as? Double

        let condition = WeatherConditionStrings.from(owmCode: conditionCode, description: conditionDesc)
        var summary = "\(condition), \(String(format: "%.0f", temp))°C"
        if let precipMm, precipMm > 0 {
            summary += ", \(String(format: "%.1f", precipMm))mm rain"
        }

        return WeatherSnapshot(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            fetchedAt: Date(),
            forecastDate: Date(),
            condition: condition,
            temperatureCelsius: temp,
            precipitationChance: precipMm != nil ? min(precipMm! / 10.0, 1.0) : 0,
            windSpeedKph: windSpeedKph,
            summary: summary,
            humidity: humidity.map { $0 / 100.0 },
            feelsLikeCelsius: feelsLike,
            visibility: visibility,
            pressure: pressure,
            highTemp: tempMax,
            lowTemp: tempMin,
            sunrise: sunrise,
            sunset: sunset,
            cloudCover: cloudCover
        )
    }

    // MARK: - Comprehensive API (WeatherViewModel)

    func fetchWeather(for coordinate: Coordinate, jwt: String?, context: ModelContext) async throws -> (current: WeatherSnapshot, hourly: [WeatherSnapshot], daily: [WeatherSnapshot]) {
        let key = resolveAPIKey()
        async let current = fetchCurrentWeather(coordinate: coordinate)
        async let forecastResult = fetchForecast(coordinate: coordinate, key: key, context: context)

        let currentSnapshot = try await current
        let (hourly, daily) = try await forecastResult

        await MainActor.run {
            self.lastSource = "OpenWeatherMap"
            self.currentSnapshot = currentSnapshot
            self.hourlyForecast = hourly
            self.dailyForecast = daily
        }

        // Fetch air quality in background
        if let aqi = try? await fetchAirPollution(latitude: coordinate.latitude, longitude: coordinate.longitude, key: key) {
            await MainActor.run {
                self.currentSnapshot?.airQualityIndex = aqi
                try? context.save()
            }
        }

        context.insert(currentSnapshot)
        for h in hourly { context.insert(h) }
        for d in daily { context.insert(d) }
        try? context.save()

        return (currentSnapshot, hourly, daily)
    }

    // MARK: - OpenWeatherMap Forecast API

    private func fetchForecast(coordinate: Coordinate, key: String, context: ModelContext) async throws -> (hourly: [WeatherSnapshot], daily: [WeatherSnapshot]) {
        let urlString = "https://api.openweathermap.org/data/2.5/forecast?lat=\(coordinate.latitude)&lon=\(coordinate.longitude)&units=metric&cnt=40&appid=\(key)"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "WeatherService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid OWM forecast URL"])
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = json["list"] as? [[String: Any]] else {
            throw NSError(domain: "WeatherService", code: 500)
        }

        let now = Date()

        // Parse hourly entries (3-hour intervals)
        var hourlySnapshots: [WeatherSnapshot] = []
        for entry in list.prefix(48) {
            guard let timestamp = entry["dt"] as? TimeInterval else { continue }
            let forecastDate = Date(timeIntervalSince1970: timestamp)

            let main = entry["main"] as? [String: Any]
            let temp = main?["temp"] as? Double ?? 0
            let humidity = main?["humidity"] as? Double
            let feelsLike = main?["feels_like"] as? Double

            let wind = entry["wind"] as? [String: Any]
            let windSpeedMs = wind?["speed"] as? Double
            let windSpeedKph = windSpeedMs.map { $0 * 3.6 }

            let weatherArr = entry["weather"] as? [[String: Any]]
            let firstWeather = weatherArr?.first
            let conditionCode = firstWeather?["id"] as? Int ?? 800
            let conditionDesc = firstWeather?["description"] as? String ?? "clear sky"

            let clouds = entry["clouds"] as? [String: Any]
            let cloudCover = clouds?["all"] as? Double

            let pop = entry["pop"] as? Double ?? 0  // probability of precipitation 0-1

            let condition = WeatherConditionStrings.from(owmCode: conditionCode, description: conditionDesc)

            let snapshot = WeatherSnapshot(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                fetchedAt: now,
                forecastDate: forecastDate,
                condition: condition,
                temperatureCelsius: temp,
                precipitationChance: pop,
                windSpeedKph: windSpeedKph,
                summary: "\(condition), \(String(format: "%.0f", temp))°C",
                humidity: humidity.map { $0 / 100.0 },
                feelsLikeCelsius: feelsLike,
                cloudCover: cloudCover
            )
            context.insert(snapshot)
            hourlySnapshots.append(snapshot)
        }

        // Build daily forecast from 3-hour intervals
        let calendar = Calendar.current
        var dailyGroups: [Date: [WeatherSnapshot]] = [:]
        for snapshot in hourlySnapshots {
            let dayStart = calendar.startOfDay(for: snapshot.forecastDate)
            dailyGroups[dayStart, default: []].append(snapshot)
        }

        var dailySnapshots: [WeatherSnapshot] = []
        let sortedDays = dailyGroups.keys.sorted().prefix(8)
        for dayStart in sortedDays {
            guard let entries = dailyGroups[dayStart], !entries.isEmpty else { continue }
            let maxT = entries.map(\.temperatureCelsius).max() ?? 0
            let minT = entries.map(\.temperatureCelsius).min() ?? 0
            let avgHumidity = entries.compactMap(\.humidity).reduce(0, +) / Double(entries.compactMap(\.humidity).count)
            let maxPrecip = entries.map(\.precipitationChance).max() ?? 0
            let maxWind = entries.compactMap(\.windSpeedKph).max()
            let condition = entries.map(\.condition).mostFrequent() ?? "Clear"
            let maxCloud = entries.compactMap(\.cloudCover).max()

            let summary = "\(condition), H:\(String(format: "%.0f", maxT))° L:\(String(format: "%.0f", minT))°"

            let daily = WeatherSnapshot(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                fetchedAt: now,
                forecastDate: dayStart,
                condition: condition,
                temperatureCelsius: maxT,
                precipitationChance: maxPrecip,
                windSpeedKph: maxWind,
                summary: summary,
                humidity: avgHumidity.isNaN ? nil : avgHumidity,
                feelsLikeCelsius: nil,
                cloudCover: maxCloud,
                highTemp: maxT,
                lowTemp: minT
            )
            context.insert(daily)
            dailySnapshots.append(daily)
        }

        return (hourlySnapshots, dailySnapshots)
    }

    // MARK: - Air Pollution

    func fetchAirQuality(latitude: Double, longitude: Double) async throws -> Int? {
        let key = resolveAPIKey()
        return try await fetchAirPollution(latitude: latitude, longitude: longitude, key: key)
    }

    private func fetchAirPollution(latitude: Double, longitude: Double, key: String) async throws -> Int? {
        let urlString = "https://api.openweathermap.org/data/2.5/air_pollution?lat=\(latitude)&lon=\(longitude)&appid=\(key)"
        guard let url = URL(string: urlString) else { return nil }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = json["list"] as? [[String: Any]],
              let first = list.first,
              let main = first["main"] as? [String: Any],
              let aqi = main["aqi"] as? Int else { return nil }

        return aqi
    }

    // MARK: - API Key Resolution

    private func resolveAPIKey() -> String {
        OpenWeatherAPI.defaultKey
    }

    // MARK: - Summaries

    func generateDetailedSummary(from snapshot: WeatherSnapshot) -> String {
        var parts: [String] = []
        parts.append("\(snapshot.condition), \(String(format: "%.0f", snapshot.temperatureCelsius))°C")
        if let feelsLike = snapshot.feelsLikeCelsius {
            parts.append("Feels like \(String(format: "%.0f", feelsLike))°C")
        }
        if let humidity = snapshot.humidity {
            parts.append("Humidity: \(String(format: "%.0f", humidity * 100))%")
        }
        if let wind = snapshot.windSpeedKph {
            parts.append("Wind: \(String(format: "%.0f", wind)) km/h")
        }
        if let uvIndex = snapshot.uvIndex {
            parts.append("UV Index: \(uvIndex)")
        }
        if let visibility = snapshot.visibility {
            parts.append("Visibility: \(String(format: "%.1f", visibility / 1000)) km")
        }
        if let pressure = snapshot.pressure {
            parts.append("Pressure: \(String(format: "%.0f", pressure)) hPa")
        }
        if let cloudCover = snapshot.cloudCover {
            parts.append("Cloud cover: \(Int(cloudCover))%")
        }
        if let dewPoint = snapshot.dewPointCelsius {
            parts.append("Dew point: \(String(format: "%.0f", dewPoint))°C")
        }
        if let aqi = snapshot.airQualityIndex {
            parts.append("Air quality index: \(aqi)")
        }
        if snapshot.precipitationChance > 0.3 {
            parts.append("\(Int(snapshot.precipitationChance * 100))% chance of precipitation")
        }
        return parts.joined(separator: ". ")
    }

    func generateWeatherSummary(weather: WeatherSnapshot?) -> String {
        guard let weather else { return "Weather data unavailable" }
        var summary = "\(weather.condition), \(String(format: "%.0f", weather.temperatureCelsius))°C"
        if let feelsLike = weather.feelsLikeCelsius {
            summary += " (feels like \(String(format: "%.0f", feelsLike))°C)"
        }
        if weather.precipitationChance > 0.3 {
            summary += ", \(Int(weather.precipitationChance * 100))% rain"
        }
        if let wind = weather.windSpeedKph, wind > 20 {
            summary += ", windy (\(String(format: "%.0f", wind)) km/h)"
        }
        if let uv = weather.uvIndex, uv >= 6 {
            summary += ", UV Index \(uv)"
        }
        return summary
    }

    // MARK: - Alert Helpers

    func shouldNotifyRain(snapshot: WeatherSnapshot, threshold: Double) -> Bool {
        snapshot.precipitationChance >= threshold
    }

    func shouldNotifyHeat(temp: Double, threshold: Double) -> Bool {
        temp >= threshold
    }

    func shouldNotifyCold(temp: Double, threshold: Double) -> Bool {
        temp <= threshold
    }

    func isGoodOutdoorWeather(snapshot: WeatherSnapshot) -> Bool {
        snapshot.precipitationChance < 0.3
            && snapshot.temperatureCelsius > 10
            && snapshot.temperatureCelsius < 30
            && (snapshot.windSpeedKph ?? 0) < 30
    }
}

// MARK: - API Key Configuration

enum OpenWeatherAPI {
    /// OpenWeatherMap API key — used for all weather data requests.
    static let defaultKey = "83bee33aeab595bba6f3742da3c2f2a1"
}

// MARK: - Condition String Mapping

enum WeatherConditionStrings {
    /// Map OpenWeatherMap condition code + description to a SummerCal condition label.
    static func from(owmCode: Int, description: String) -> String {
        switch owmCode {
        // Thunderstorm
        case 200...232: return "Thunderstorm"
        // Drizzle
        case 300...321: return "Drizzle"
        // Rain
        case 500...504, 520...531: return "Rain"
        case 511: return "Freezing Rain"
        // Snow
        case 600...622: return "Snow"
        // Atmosphere
        case 701: return "Mist"
        case 711: return "Smoke"
        case 721: return "Haze"
        case 731, 761: return "Dust"
        case 741: return "Fog"
        case 751: return "Sand"
        case 762: return "Ash"
        case 771: return "Squall"
        case 781: return "Tornado"
        // Clear
        case 800: return "Clear"
        // Clouds
        case 801: return "Partly Cloudy"
        case 802: return "Scattered Clouds"
        case 803, 804: return "Cloudy"
        default: return description.capitalized
        }
    }

    static func iconName(for condition: String) -> String {
        switch condition {
        case "Clear": return "sun.max.fill"
        case "Partly Cloudy", "Scattered Clouds": return "cloud.sun.fill"
        case "Cloudy", "Overcast": return "cloud.fill"
        case "Fog", "Mist", "Haze", "Smoke": return "cloud.fog.fill"
        case "Drizzle": return "cloud.drizzle.fill"
        case "Rain", "Freezing Rain": return "cloud.rain.fill"
        case "Snow": return "cloud.snow.fill"
        case "Windy", "Squall": return "wind"
        case "Thunderstorm": return "cloud.bolt.rain.fill"
        case "Dust", "Sand", "Ash": return "sun.dust.fill"
        case "Tornado": return "tornado"
        default: return "questionmark"
        }
    }
}

// MARK: - Array Extension (most frequent element)

extension Array where Element: Hashable {
    func mostFrequent() -> Element? {
        let grouped = Dictionary(grouping: self, by: { $0 })
        return grouped.max(by: { $0.value.count < $1.value.count })?.key
    }
}
