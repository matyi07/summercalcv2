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
    var lastUpdated: Date?
    var weatherSource: String { weatherService.lastSource }

    var rainAlertEnabled: Bool = true
    var rainThreshold: Double = 0.5
    var heatAlertEnabled: Bool = true
    var heatThreshold: Double = 35
    var coldAlertEnabled: Bool = true
    var coldThreshold: Double = 0

    private let locationManager = CLLocationManager()
    private var currentCoordinate: CLLocationCoordinate2D?
    private let weatherService = WeatherService()

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
            await MainActor.run { errorMessage = "Location not available" }
            return
        }

        await MainActor.run { isLoading = true; errorMessage = nil }

        let settings = UserSettings.current(in: modelContext)
        let jwt = settings.weatherKitJWT
        let coord = Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)

        do {
            let result = try await weatherService.fetchWeather(for: coord, jwt: jwt, context: modelContext)
            await MainActor.run {
                self.currentWeather = result.current
                self.hourlyForecast = result.hourly
                self.dailyForecast = result.daily
                self.lastUpdated = Date()
                try? modelContext.save()
            }

            // Fetch air quality asynchronously
            Task {
                if let aqi = try? await weatherService.fetchAirQuality(latitude: coordinate.latitude, longitude: coordinate.longitude) {
                    await MainActor.run {
                        self.currentWeather?.airQualityIndex = aqi
                        try? modelContext.save()
                    }
                }
            }
        } catch {
            await MainActor.run { self.errorMessage = error.localizedDescription }
        }

        await MainActor.run { isLoading = false }
    }

    func retry(modelContext: ModelContext) {
        Task { await fetchWeather(modelContext: modelContext) }
    }

    func weatherIcon(for condition: String) -> String {
        WeatherConditionStrings.iconName(for: condition)
    }

    func checkAlerts() -> [String] {
        var alerts: [String] = []
        guard let weather = currentWeather else { return alerts }

        if rainAlertEnabled && weather.precipitationChance >= rainThreshold {
            alerts.append("Rain alert: \(Int(weather.precipitationChance * 100))% chance of precipitation")
        }
        if heatAlertEnabled && weather.temperatureCelsius >= heatThreshold {
            alerts.append("Heat alert: \(String(format: "%.0f", weather.temperatureCelsius))°C exceeds threshold of \(Int(heatThreshold))°C")
        }
        if coldAlertEnabled && weather.temperatureCelsius <= coldThreshold {
            alerts.append("Cold alert: \(String(format: "%.0f", weather.temperatureCelsius))°C is below threshold of \(Int(coldThreshold))°C")
        }
        return alerts
    }

    func formattedTemperature(_ celsius: Double) -> String {
        String(format: "%.0f°C", celsius)
    }

    func formattedWind(_ kph: Double?) -> String {
        guard let kph else { return "--" }
        return String(format: "%.0f km/h", kph)
    }

    func formattedHumidity(_ humidity: Double?) -> String {
        guard let humidity else { return "--" }
        return String(format: "%.0f%%", humidity * 100)
    }

    func formattedVisibility(_ meters: Double?) -> String {
        guard let meters else { return "--" }
        return String(format: "%.1f km", meters / 1000)
    }

    func formattedPressure(_ hPa: Double?) -> String {
        guard let hPa else { return "--" }
        return String(format: "%.0f hPa", hPa)
    }

    func formattedCloudCover(_ percent: Double?) -> String {
        guard let percent else { return "--" }
        return String(format: "%.0f%%", percent)
    }

    func formattedDewPoint(_ celsius: Double?) -> String {
        guard let celsius else { return "--" }
        return String(format: "%.0f°C", celsius)
    }

    func formattedSunriseSunset(_ date: Date?) -> String {
        guard let date else { return "--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    func aqiLabel(_ index: Int?) -> String {
        guard let index else { return "--" }
        switch index {
        case 1: return "\(index) Good"
        case 2: return "\(index) Fair"
        case 3: return "\(index) Moderate"
        case 4: return "\(index) Poor"
        case 5: return "\(index) Very Poor"
        case 6: return "\(index) Severe"
        default: return "\(index)"
        }
    }

    func aqiColor(_ index: Int?) -> String {
        guard let index else { return "secondary" }
        switch index {
        case 1: return "green"
        case 2: return "yellow"
        case 3: return "orange"
        case 4: return "red"
        case 5: return "purple"
        case 6: return "brown"
        default: return "secondary"
        }
    }

    func uvIndexLabel(_ index: Int?) -> String {
        guard let index else { return "--" }
        switch index {
        case 0...2: return "\(index) Low"
        case 3...5: return "\(index) Moderate"
        case 6...7: return "\(index) High"
        case 8...10: return "\(index) Very High"
        default: return "\(index) Extreme"
        }
    }

    func uvIndexColor(_ index: Int?) -> String {
        guard let index else { return "secondary" }
        switch index {
        case 0...2: return "green"
        case 3...5: return "yellow"
        case 6...7: return "orange"
        case 8...10: return "red"
        default: return "purple"
        }
    }

    func formattedLastUpdated() -> String {
        guard let lastUpdated else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "Updated at \(formatter.string(from: lastUpdated))"
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
        // Don't stop — allow continuous tracking for when user moves
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
