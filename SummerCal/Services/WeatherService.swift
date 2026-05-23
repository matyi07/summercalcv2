import Foundation
import CoreLocation
import Combine

enum WeatherCondition: String, Codable {
    case sunny, cloudy, partlyCloudy, rainy, snowy, windy, stormy, foggy, unknown
}

final class WeatherService: ObservableObject {
    @Published var currentSnapshot: WeatherSnapshot?
    @Published var hourlyForecast: [WeatherSnapshot] = []
    @Published var dailyForecast: [WeatherSnapshot] = []
    @Published var isLoading = false
    @Published var error: String?
    
    func fetchWeather(for coordinate: Coordinate) async {
        await MainActor.run { isLoading = true; error = nil }
        do {
            let snapshot = try await fetchFromOpenMeteo(coordinate: coordinate)
            await MainActor.run {
                self.currentSnapshot = snapshot
                self.isLoading = false
            }
        } catch {
            await MainActor.run { self.error = error.localizedDescription; self.isLoading = false }
        }
    }
    
    private func fetchFromOpenMeteo(coordinate: Coordinate) async throws -> WeatherSnapshot {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,apparent_temperature,precipitation_probability,weather_code,wind_speed_10m"),
            URLQueryItem(name: "timezone", value: TimeZone.current.identifier)
        ]
        
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let current = json?["current"] as? [String: Any]
        
        let temp = current?["temperature_2m"] as? Double ?? 0
        let precip = (current?["precipitation_probability"] as? Double ?? 0) / 100.0
        let windSpeed = current?["wind_speed_10m"] as? Double
        let weatherCode = current?["weather_code"] as? Int ?? 0
        let condition = weatherDescription(for: weatherCode)
        
        let summary = "\(condition.capitalized), \(String(format: "%.0f", temp))°C\(precip > 0.3 ? ", \(Int(precip * 100))% chance of rain" : "")"
        
        return WeatherSnapshot(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            fetchedAt: Date(),
            forecastDate: Date(),
            condition: condition,
            temperatureCelsius: temp,
            precipitationChance: precip,
            windSpeedKph: windSpeed,
            summary: summary
        )
    }
    
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
        snapshot.precipitationChance < 0.3 && snapshot.temperatureCelsius > 10 && snapshot.temperatureCelsius < 30 && (snapshot.windSpeedKph ?? 0) < 30
    }
    
    func generateWeatherSummary(weather: WeatherSnapshot?) -> String {
        guard let weather = weather else { return "Weather data unavailable" }
        var summary = "\(weather.condition.capitalized), \(String(format: "%.0f", weather.temperatureCelsius))°C"
        if weather.precipitationChance > 0.3 { summary += ", \(Int(weather.precipitationChance * 100))% rain" }
        if let wind = weather.windSpeedKph, wind > 20 { summary += ", windy (\(String(format: "%.0f", wind)) km/h)" }
        return summary
    }
    
    private func weatherDescription(for code: Int) -> String {
        switch code {
        case 0: return "sunny"
        case 1, 2: return "partly cloudy"
        case 3: return "cloudy"
        case 45, 48: return "foggy"
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82: return "rainy"
        case 71, 73, 75, 77, 85, 86: return "snowy"
        case 95, 96, 99: return "stormy"
        default: return "unknown"
        }
    }
}
