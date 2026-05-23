import Foundation
import SwiftData
import CoreLocation

@Observable
final class WeatherViewModel: NSObject, CLLocationManagerDelegate {
    var currentWeather: WeatherSnapshot?
    var hourlyForecast: [WeatherSnapshot] = []
    var dailyForecast: [WeatherSnapshot] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var locationName: String?
    var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined

    var rainAlertEnabled: Bool = true
    var rainThreshold: Double = 0.5
    var heatAlertEnabled: Bool = true
    var heatThreshold: Double = 35
    var coldAlertEnabled: Bool = true
    var coldThreshold: Double = 0

    private let locationManager = CLLocationManager()
    private var currentCoordinate: CLLocationCoordinate2D?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
    }

    func loadThresholds(modelContext: ModelContext) {
        let settings = UserSettings.current(in: modelContext)
        rainThreshold = settings.rainThreshold
        heatThreshold = settings.heatThresholdCelsius
        coldThreshold = settings.coldThresholdCelsius
        rainAlertEnabled = settings.weatherAlertsEnabled
        heatAlertEnabled = settings.weatherAlertsEnabled
        coldAlertEnabled = settings.weatherAlertsEnabled
    }

    func saveThresholds(modelContext: ModelContext) {
        let settings = UserSettings.current(in: modelContext)
        settings.rainThreshold = rainThreshold
        settings.heatThresholdCelsius = heatThreshold
        settings.coldThresholdCelsius = coldThreshold
        settings.weatherAlertsEnabled = rainAlertEnabled || heatAlertEnabled || coldAlertEnabled
        settings.updatedAt = Date()
        try? modelContext.save()
    }

    func fetchWeather(modelContext: ModelContext) async {
        guard let coordinate = currentCoordinate else {
            errorMessage = "Location not available"
            return
        }

        isLoading = true
        errorMessage = nil

        let latitude = coordinate.latitude
        let longitude = coordinate.longitude

        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,precipitation_probability&hourly=temperature_2m,precipitation_probability,weather_code,wind_speed_10m,apparent_temperature&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,wind_speed_10m_max&timezone=auto&forecast_days=8"

        guard let url = URL(string: urlString) else {
            isLoading = false
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                isLoading = false
                errorMessage = "Failed to parse weather data"
                return
            }

            parseAndStoreWeather(json: json, latitude: latitude, longitude: longitude, modelContext: modelContext)
            try? modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func parseAndStoreWeather(json: [String: Any], latitude: Double, longitude: Double, modelContext: ModelContext) {
        if let current = json["current"] as? [String: Any] {
            let temp = current["temperature_2m"] as? Double ?? 0
            let weatherCode = current["weather_code"] as? Int ?? 0
            let windSpeed = current["wind_speed_10m"] as? Double
            let precipChance = current["precipitation_probability"] as? Double ?? 0

            let snapshot = WeatherSnapshot(
                latitude: latitude,
                longitude: longitude,
                fetchedAt: Date(),
                forecastDate: Date(),
                condition: weatherDescription(for: weatherCode),
                temperatureCelsius: temp,
                precipitationChance: precipChance,
                windSpeedKph: windSpeed,
                summary: "Now: \(weatherDescription(for: weatherCode)), \(Int(temp))°C"
            )
            currentWeather = snapshot
            modelContext.insert(snapshot)
        }

        if let hourly = json["hourly"] as? [String: Any],
           let times = hourly["time"] as? [String],
           let temps = hourly["temperature_2m"] as? [Double],
           let precipProbs = hourly["precipitation_probability"] as? [Double?],
           let weatherCodes = hourly["weather_code"] as? [Int?],
           let windSpeeds = hourly["wind_speed_10m"] as? [Double?] {

            var forecasts: [WeatherSnapshot] = []
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate, .withColonSeparatorInTime]

            for i in 0..<min(times.count, 48) {
                guard let date = formatter.date(from: times[i]) else { continue }
                let temp = i < temps.count ? temps[i] : 0
                let precip = i < precipProbs.count ? (precipProbs[i] ?? 0) : 0
                let code = i < weatherCodes.count ? (weatherCodes[i] ?? 0) : 0
                let wind = i < windSpeeds.count ? (windSpeeds[i] ?? 0) : 0

                let snapshot = WeatherSnapshot(
                    latitude: latitude,
                    longitude: longitude,
                    fetchedAt: Date(),
                    forecastDate: date,
                    condition: weatherDescription(for: code),
                    temperatureCelsius: temp,
                    precipitationChance: precip,
                    windSpeedKph: wind,
                    summary: "\(weatherDescription(for: code)), \(Int(temp))°C"
                )
                modelContext.insert(snapshot)
                forecasts.append(snapshot)
            }
            hourlyForecast = forecasts
        }

        if let daily = json["daily"] as? [String: Any],
           let times = daily["time"] as? [String],
           let maxTemps = daily["temperature_2m_max"] as? [Double],
           let minTemps = daily["temperature_2m_min"] as? [Double],
           let precipProbs = daily["precipitation_probability_max"] as? [Double?],
           let weatherCodes = daily["weather_code"] as? [Int?],
           let windSpeeds = daily["wind_speed_10m_max"] as? [Double?] {

            var dailyForecasts: [WeatherSnapshot] = []
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]

            for i in 0..<min(times.count, 8) {
                guard let date = formatter.date(from: times[i]) else { continue }
                let maxTemp = i < maxTemps.count ? maxTemps[i] : 0
                let precip = i < precipProbs.count ? (precipProbs[i] ?? 0) : 0
                let code = i < weatherCodes.count ? (weatherCodes[i] ?? 0) : 0
                let wind = i < windSpeeds.count ? (windSpeeds[i] ?? 0) : 0
                let minTemp = i < minTemps.count ? minTemps[i] : 0

                let snapshot = WeatherSnapshot(
                    latitude: latitude,
                    longitude: longitude,
                    fetchedAt: Date(),
                    forecastDate: date,
                    condition: weatherDescription(for: code),
                    temperatureCelsius: maxTemp,
                    precipitationChance: precip,
                    windSpeedKph: wind,
                    summary: "\(weatherDescription(for: code)), H:\(Int(maxTemp))° L:\(Int(minTemp))°"
                )
                modelContext.insert(snapshot)
                dailyForecasts.append(snapshot)
            }
            dailyForecast = dailyForecasts
        }
    }

    func weatherDescription(for code: Int) -> String {
        switch code {
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

    func weatherIcon(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
        case 61, 63, 65, 66, 67: return "cloud.rain.fill"
        case 71, 73, 75, 77: return "cloud.snow.fill"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "questionmark"
        }
    }

    func checkAlerts() -> [String] {
        var alerts: [String] = []
        guard let weather = currentWeather else { return alerts }

        if rainAlertEnabled && weather.precipitationChance >= rainThreshold {
            alerts.append("Rain alert: \(Int(weather.precipitationChance))% chance of precipitation")
        }
        if heatAlertEnabled && weather.temperatureCelsius >= heatThreshold {
            alerts.append("Heat alert: \(Int(weather.temperatureCelsius))°C exceeds threshold of \(Int(heatThreshold))°C")
        }
        if coldAlertEnabled && weather.temperatureCelsius <= coldThreshold {
            alerts.append("Cold alert: \(Int(weather.temperatureCelsius))°C is below threshold of \(Int(coldThreshold))°C")
        }
        return alerts
    }

    func formattedTemperature(_ celsius: Double) -> String {
        String(format: "%.0f°C", celsius)
    }

    func formattedWind(_ kph: Double?) -> String {
        guard let kph = kph else { return "--" }
        return String(format: "%.0f km/h", kph)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationAuthorizationStatus = manager.authorizationStatus
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            locationName = nil
            currentCoordinate = nil
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentCoordinate = location.coordinate
        manager.stopUpdatingLocation()

        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            self?.locationName = placemarks?.first?.locality ?? placemarks?.first?.name
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = "Location error: \(error.localizedDescription)"
    }
}
