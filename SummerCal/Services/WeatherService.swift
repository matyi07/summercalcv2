import Foundation
import CoreLocation
import SwiftData

enum WeatherCondition: String, Codable {
    case sunny, cloudy, partlyCloudy, rainy, snowy, windy, stormy, foggy, unknown
}

final class WeatherService: ObservableObject {
    @Published var currentSnapshot: WeatherSnapshot?
    @Published var hourlyForecast: [WeatherSnapshot] = []
    @Published var dailyForecast: [WeatherSnapshot] = []
    @Published var isLoading = false
    @Published var error: String?

    private let weatherKitBaseURL = "https://weatherkit.apple.com/api/v1/weather/en"

    // MARK: - Legacy API (TodayView / ContentView compatibility)

    func fetchWeather(for coordinate: Coordinate) async {
        await MainActor.run { isLoading = true; error = nil }
        do {
            let snapshot = try await fetchOpenMeteoCurrent(coordinate: coordinate)
            await MainActor.run {
                self.currentSnapshot = snapshot
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func fetchOpenMeteoCurrent(coordinate: Coordinate) async throws -> WeatherSnapshot {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(coordinate.latitude)&longitude=\(coordinate.longitude)&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,precipitation_probability&timezone=auto"

        guard let url = URL(string: urlString) else {
            throw NSError(domain: "WeatherService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Open-Meteo URL"])
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "WeatherService", code: 500)
        }

        let currentDict = json["current"] as? [String: Any]
        let temp = currentDict?["temperature_2m"] as? Double ?? 0
        let humidity = currentDict?["relative_humidity_2m"] as? Double
        let feelsLike = currentDict?["apparent_temperature"] as? Double
        let wmoCode = currentDict?["weather_code"] as? Int ?? 0
        let windSpeed = currentDict?["wind_speed_10m"] as? Double
        let rawPrecip = currentDict?["precipitation_probability"] as? Double ?? 0
        let precipChance = rawPrecip / 100.0

        let condition = WeatherConditionStrings.from(wmoCode: wmoCode)
        let summary = "\(condition), \(String(format: "%.0f", temp))°C\(precipChance > 0.3 ? ", \(Int(precipChance * 100))% rain" : "")"

        return WeatherSnapshot(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            fetchedAt: Date(),
            forecastDate: Date(),
            condition: condition,
            temperatureCelsius: temp,
            precipitationChance: precipChance,
            windSpeedKph: windSpeed,
            summary: summary,
            humidity: humidity,
            feelsLikeCelsius: feelsLike
        )
    }

    // MARK: - Comprehensive API (WeatherViewModel)

    func fetchWeather(for coordinate: Coordinate, jwt: String?, context: ModelContext) async throws -> (current: WeatherSnapshot, hourly: [WeatherSnapshot], daily: [WeatherSnapshot]) {
        if let jwt, !jwt.isEmpty {
            do {
                let result = try await fetchFromWeatherKit(coordinate: coordinate, jwt: jwt, context: context)
                await MainActor.run {
                    self.currentSnapshot = result.current
                    self.hourlyForecast = result.hourly
                    self.dailyForecast = result.daily
                }
                return result
            } catch {
                let result = try await fetchFromOpenMeteo(coordinate: coordinate, context: context)
                await MainActor.run {
                    self.currentSnapshot = result.current
                    self.hourlyForecast = result.hourly
                    self.dailyForecast = result.daily
                }
                return result
            }
        }

        let result = try await fetchFromOpenMeteo(coordinate: coordinate, context: context)
        await MainActor.run {
            self.currentSnapshot = result.current
            self.hourlyForecast = result.hourly
            self.dailyForecast = result.daily
        }
        return result
    }

    // MARK: - WeatherKit REST API

    private func fetchFromWeatherKit(coordinate: Coordinate, jwt: String, context: ModelContext) async throws -> (current: WeatherSnapshot, hourly: [WeatherSnapshot], daily: [WeatherSnapshot]) {
        let urlString = "\(weatherKitBaseURL)/\(coordinate.latitude)/\(coordinate.longitude)?dataSets=currentWeather,forecastHourly,forecastDaily"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "WeatherService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid WeatherKit URL"])
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(jwt)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 500
            throw NSError(domain: "WeatherService", code: status, userInfo: [NSLocalizedDescriptionKey: "WeatherKit API returned \(status)"])
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "WeatherService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid WeatherKit JSON"])
        }

        return parseWeatherKitResponse(json, coordinate: coordinate, context: context)
    }

    private func parseWeatherKitResponse(_ json: [String: Any], coordinate: Coordinate, context: ModelContext) -> (current: WeatherSnapshot, hourly: [WeatherSnapshot], daily: [WeatherSnapshot]) {
        let now = Date()
        let current = parseCurrentWeather(json["currentWeather"] as? [String: Any], coordinate: coordinate, now: now, context: context)
        let hourly = parseHourlyForecast(json["forecastHourly"] as? [String: Any], coordinate: coordinate, now: now, context: context)
        let daily = parseDailyForecast(json["forecastDaily"] as? [String: Any], coordinate: coordinate, now: now, context: context)
        return (current, hourly, daily)
    }

    private func parseCurrentWeather(_ dict: [String: Any]?, coordinate: Coordinate, now: Date, context: ModelContext) -> WeatherSnapshot {
        let temp = dict?["temperature"] as? Double ?? 0
        let conditionCode = dict?["conditionCode"] as? String ?? "Clear"
        let humidity = dict?["humidity"] as? Double
        let feelsLike = dict?["temperatureApparent"] as? Double
        let windSpeed = dict?["windSpeed"] as? Double
        let uvIndex = dict?["uvIndex"] as? Int
        let visibility = dict?["visibility"] as? Double
        let pressure = dict?["pressure"] as? Double
        let precipChance = dict?["precipitationChance"] as? Double ?? 0

        let condition = WeatherConditionStrings.from(appleCode: conditionCode)
        let summary = buildCurrentSummary(condition: condition, temp: temp, feelsLike: feelsLike, precipChance: precipChance)

        let snapshot = WeatherSnapshot(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            fetchedAt: now,
            forecastDate: now,
            condition: condition,
            temperatureCelsius: temp,
            precipitationChance: precipChance,
            windSpeedKph: windSpeed,
            summary: summary,
            humidity: humidity,
            feelsLikeCelsius: feelsLike,
            uvIndex: uvIndex,
            visibility: visibility,
            pressure: pressure
        )
        context.insert(snapshot)
        return snapshot
    }

    private func parseHourlyForecast(_ dict: [String: Any]?, coordinate: Coordinate, now: Date, context: ModelContext) -> [WeatherSnapshot] {
        guard let hours = dict?["hours"] as? [[String: Any]] else { return [] }

        let isoFull = ISO8601DateFormatter()
        isoFull.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let isoBasic = ISO8601DateFormatter()
        isoBasic.formatOptions = [.withInternetDateTime]

        return hours.prefix(48).compactMap { hour in
            guard let timeStr = hour["forecastStart"] as? String else { return nil }
            let date = isoFull.date(from: timeStr) ?? isoBasic.date(from: timeStr)
            guard let forecastDate = date else { return nil }

            let temp = hour["temperature"] as? Double ?? 0
            let conditionCode = hour["conditionCode"] as? String ?? "Clear"
            let precipChance = hour["precipitationChance"] as? Double ?? 0
            let windSpeed = hour["windSpeed"] as? Double
            let humidity = hour["humidity"] as? Double
            let feelsLike = hour["temperatureApparent"] as? Double

            let condition = WeatherConditionStrings.from(appleCode: conditionCode)
            let summary = "\(condition), \(String(format: "%.0f", temp))°C"

            let snapshot = WeatherSnapshot(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                fetchedAt: now,
                forecastDate: forecastDate,
                condition: condition,
                temperatureCelsius: temp,
                precipitationChance: precipChance,
                windSpeedKph: windSpeed,
                summary: summary,
                humidity: humidity,
                feelsLikeCelsius: feelsLike
            )
            context.insert(snapshot)
            return snapshot
        }
    }

    private func parseDailyForecast(_ dict: [String: Any]?, coordinate: Coordinate, now: Date, context: ModelContext) -> [WeatherSnapshot] {
        guard let days = dict?["days"] as? [[String: Any]] else { return [] }

        let isoFull = ISO8601DateFormatter()
        isoFull.formatOptions = [.withFullDate]

        let isoDateTime = ISO8601DateFormatter()
        isoDateTime.formatOptions = [.withInternetDateTime]

        return days.prefix(8).compactMap { day in
            guard let timeStr = day["forecastStart"] as? String else { return nil }
            let date = isoFull.date(from: timeStr) ?? isoDateTime.date(from: timeStr)
            guard let forecastDate = date else { return nil }

            let maxTemp = day["temperatureMax"] as? Double ?? 0
            let minTemp = day["temperatureMin"] as? Double ?? 0
            let conditionCode = day["conditionCode"] as? String ?? "Clear"
            let precipChance = day["precipitationChance"] as? Double ?? 0
            let windSpeed = day["windSpeed"] as? Double
            let humidity = day["humidity"] as? Double

            let condition = WeatherConditionStrings.from(appleCode: conditionCode)
            let summary = "\(condition), H:\(String(format: "%.0f", maxTemp))° L:\(String(format: "%.0f", minTemp))°"

            let snapshot = WeatherSnapshot(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                fetchedAt: now,
                forecastDate: forecastDate,
                condition: condition,
                temperatureCelsius: maxTemp,
                precipitationChance: precipChance,
                windSpeedKph: windSpeed,
                summary: summary,
                humidity: humidity,
                highTemp: maxTemp,
                lowTemp: minTemp
            )
            context.insert(snapshot)
            return snapshot
        }
    }

    // MARK: - Open-Meteo Fallback

    private func fetchFromOpenMeteo(coordinate: Coordinate, context: ModelContext) async throws -> (current: WeatherSnapshot, hourly: [WeatherSnapshot], daily: [WeatherSnapshot]) {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(coordinate.latitude)&longitude=\(coordinate.longitude)&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,precipitation_probability&hourly=temperature_2m,precipitation_probability,weather_code,wind_speed_10m,apparent_temperature&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,wind_speed_10m_max&timezone=auto&forecast_days=8"

        guard let url = URL(string: urlString) else {
            throw NSError(domain: "WeatherService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Open-Meteo URL"])
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "WeatherService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid Open-Meteo JSON"])
        }

        return parseOpenMeteoResponse(json, coordinate: coordinate, context: context)
    }

    private func parseOpenMeteoResponse(_ json: [String: Any], coordinate: Coordinate, context: ModelContext) -> (current: WeatherSnapshot, hourly: [WeatherSnapshot], daily: [WeatherSnapshot]) {
        let now = Date()

        let currentDict = json["current"] as? [String: Any]
        let temp = currentDict?["temperature_2m"] as? Double ?? 0
        let humidity = currentDict?["relative_humidity_2m"] as? Double
        let feelsLike = currentDict?["apparent_temperature"] as? Double
        let wmoCode = currentDict?["weather_code"] as? Int ?? 0
        let windSpeed = currentDict?["wind_speed_10m"] as? Double
        let rawPrecip = currentDict?["precipitation_probability"] as? Double ?? 0
        let precipChance = rawPrecip / 100.0

        let condition = WeatherConditionStrings.from(wmoCode: wmoCode)
        let summary = "\(condition), \(String(format: "%.0f", temp))°C\(precipChance > 0.3 ? ", \(Int(precipChance * 100))% rain" : "")"

        let current = WeatherSnapshot(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            fetchedAt: now,
            forecastDate: now,
            condition: condition,
            temperatureCelsius: temp,
            precipitationChance: precipChance,
            windSpeedKph: windSpeed,
            summary: summary,
            humidity: humidity,
            feelsLikeCelsius: feelsLike
        )
        context.insert(current)

        var hourlySnapshots: [WeatherSnapshot] = []
        if let hourly = json["hourly"] as? [String: Any],
           let times = hourly["time"] as? [String],
           let temps = hourly["temperature_2m"] as? [Double],
           let precipProbs = hourly["precipitation_probability"] as? [Double?],
           let weatherCodes = hourly["weather_code"] as? [Int?],
           let windSpeeds = hourly["wind_speed_10m"] as? [Double?] {

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate, .withColonSeparatorInTime]

            for i in 0..<min(times.count, 48) {
                guard let date = formatter.date(from: times[i]) else { continue }
                let hTemp = i < temps.count ? temps[i] : 0
                let hPrecip = i < precipProbs.count ? ((precipProbs[i] ?? 0) / 100.0) : 0
                let hCode = i < weatherCodes.count ? (weatherCodes[i] ?? 0) : 0
                let hWind = i < windSpeeds.count ? (windSpeeds[i] ?? 0) : 0
                let hCondition = WeatherConditionStrings.from(wmoCode: hCode)

                let snapshot = WeatherSnapshot(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    fetchedAt: now,
                    forecastDate: date,
                    condition: hCondition,
                    temperatureCelsius: hTemp,
                    precipitationChance: hPrecip,
                    windSpeedKph: hWind,
                    summary: "\(hCondition), \(String(format: "%.0f", hTemp))°C"
                )
                context.insert(snapshot)
                hourlySnapshots.append(snapshot)
            }
        }

        var dailySnapshots: [WeatherSnapshot] = []
        if let daily = json["daily"] as? [String: Any],
           let times = daily["time"] as? [String],
           let maxTemps = daily["temperature_2m_max"] as? [Double],
           let minTemps = daily["temperature_2m_min"] as? [Double],
           let precipProbs = daily["precipitation_probability_max"] as? [Double?],
           let weatherCodes = daily["weather_code"] as? [Int?],
           let windSpeeds = daily["wind_speed_10m_max"] as? [Double?] {

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]

            for i in 0..<min(times.count, 8) {
                guard let date = formatter.date(from: times[i]) else { continue }
                let dMax = i < maxTemps.count ? maxTemps[i] : 0
                let dMin = i < minTemps.count ? minTemps[i] : 0
                let dPrecip = i < precipProbs.count ? ((precipProbs[i] ?? 0) / 100.0) : 0
                let dCode = i < weatherCodes.count ? (weatherCodes[i] ?? 0) : 0
                let dWind = i < windSpeeds.count ? (windSpeeds[i] ?? 0) : 0
                let dCondition = WeatherConditionStrings.from(wmoCode: dCode)

                let snapshot = WeatherSnapshot(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    fetchedAt: now,
                    forecastDate: date,
                    condition: dCondition,
                    temperatureCelsius: dMax,
                    precipitationChance: dPrecip,
                    windSpeedKph: dWind,
                    summary: "\(dCondition), H:\(String(format: "%.0f", dMax))° L:\(String(format: "%.0f", dMin))°",
                    highTemp: dMax,
                    lowTemp: dMin
                )
                context.insert(snapshot)
                dailySnapshots.append(snapshot)
            }
        }

        return (current, hourlySnapshots, dailySnapshots)
    }

    // MARK: - Condition Helpers

    func mapWeatherCondition(_ code: String) -> WeatherCondition {
        switch code {
        case "Clear", "MostlyClear", "Hot": return .sunny
        case "Cloudy", "MostlyCloudy", "Overcast": return .cloudy
        case "PartlyCloudy", "PartlySunny": return .partlyCloudy
        case "Drizzle", "Rain", "HeavyRain", "FreezingDrizzle", "FreezingRain": return .rainy
        case "Snow", "HeavySnow", "Sleet", "Blizzard", "BlowingSnow": return .snowy
        case "Windy", "Breezy": return .windy
        case "IsolatedThunderstorms", "ScatteredThunderstorms", "Thunderstorms", "TropicalStorm", "Hurricane": return .stormy
        case "Fog", "Haze", "Smoke": return .foggy
        default: return .unknown
        }
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

    private func buildCurrentSummary(condition: String, temp: Double, feelsLike: Double?, precipChance: Double) -> String {
        var summary = "\(condition), \(String(format: "%.0f", temp))°C"
        if let fl = feelsLike {
            summary += " (feels like \(String(format: "%.0f", fl))°C)"
        }
        if precipChance > 0.3 {
            summary += ", \(Int(precipChance * 100))% rain"
        }
        return summary
    }
}

// MARK: - Condition String Mapping

enum WeatherConditionStrings {
    static func from(appleCode: String) -> String {
        switch appleCode {
        case "Clear", "MostlyClear", "Hot": return "Clear"
        case "Cloudy", "MostlyCloudy", "Overcast": return "Cloudy"
        case "PartlyCloudy", "PartlySunny": return "Partly Cloudy"
        case "Drizzle", "Rain", "HeavyRain", "FreezingDrizzle", "FreezingRain": return "Rain"
        case "Snow", "HeavySnow", "Sleet", "Blizzard", "BlowingSnow": return "Snow"
        case "Windy", "Breezy": return "Windy"
        case "IsolatedThunderstorms", "ScatteredThunderstorms", "Thunderstorms", "TropicalStorm", "Hurricane": return "Thunderstorm"
        case "Fog", "Haze", "Smoke": return "Fog"
        default: return "Clear"
        }
    }

    static func from(wmoCode: Int) -> String {
        switch wmoCode {
        case 0: return "Clear"
        case 1, 2, 3: return "Partly Cloudy"
        case 45, 48: return "Fog"
        case 51, 53, 55: return "Drizzle"
        case 56, 57: return "Freezing Drizzle"
        case 61, 63, 65: return "Rain"
        case 66, 67: return "Freezing Rain"
        case 71, 73, 75: return "Snow"
        case 77: return "Snow Grains"
        case 80, 81, 82: return "Rain Showers"
        case 85, 86: return "Snow Showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm with Hail"
        default: return "Unknown"
        }
    }

    static func iconName(for condition: String) -> String {
        switch condition {
        case "Clear": return "sun.max.fill"
        case "Partly Cloudy": return "cloud.sun.fill"
        case "Cloudy": return "cloud.fill"
        case "Fog", "Haze": return "cloud.fog.fill"
        case "Drizzle", "Freezing Drizzle": return "cloud.drizzle.fill"
        case "Rain", "Freezing Rain", "Rain Showers": return "cloud.rain.fill"
        case "Snow", "Snow Grains", "Snow Showers": return "cloud.snow.fill"
        case "Windy": return "wind"
        case "Thunderstorm", "Thunderstorm with Hail": return "cloud.bolt.rain.fill"
        default: return "questionmark"
        }
    }
}
