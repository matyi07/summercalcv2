import Foundation
import SwiftData
import CoreLocation

enum PlaceCategory: String, CaseIterable, Identifiable {
    case all
    case cafe
    case gym
    case restaurant
    case park
    case museum
    case shop
    case errand

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All"
        case .cafe: return "Cafes"
        case .gym: return "Gyms"
        case .restaurant: return "Restaurants"
        case .park: return "Parks"
        case .museum: return "Museums"
        case .shop: return "Shops"
        case .errand: return "Errands"
        }
    }

    var icon: String {
        switch self {
        case .all: return "mappin.circle"
        case .cafe: return "cup.and.saucer"
        case .gym: return "dumbbell"
        case .restaurant: return "fork.knife"
        case .park: return "leaf"
        case .museum: return "building.columns"
        case .shop: return "bag"
        case .errand: return "checklist"
        }
    }

    var searchKeyword: String? {
        switch self {
        case .all: return nil
        case .cafe: return "cafe"
        case .gym: return "gym"
        case .restaurant: return "restaurant"
        case .park: return "park"
        case .museum: return "museum"
        case .shop: return "shop"
        case .errand: return "errand"
        }
    }
}

@Observable
final class PlacesViewModel: NSObject, CLLocationManagerDelegate {
    var searchText: String = ""
    var selectedCategory: PlaceCategory = .all
    var isMapView: Bool = false
    var placeResults: [PlaceCandidate] = []
    var savedPlaces: [PlaceCandidate] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    var currentLocationName: String?

    private let locationManager = CLLocationManager()
    private var currentCoordinate: CLLocationCoordinate2D?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
    }

    func loadSavedPlaces(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<PlaceCandidate>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        savedPlaces = (try? modelContext.fetch(descriptor)) ?? []
        if selectedCategory == .all && searchText.isEmpty {
            placeResults = savedPlaces
        } else {
            applyFilters()
        }
    }

    func applyFilters() {
        var filtered = savedPlaces

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            filtered = filtered.filter {
                $0.name.lowercased().contains(query) ||
                ($0.address?.lowercased().contains(query) ?? false) ||
                ($0.category?.lowercased().contains(query) ?? false)
            }
        }

        if selectedCategory != .all, let keyword = selectedCategory.searchKeyword {
            filtered = filtered.filter {
                $0.category?.lowercased().contains(keyword) ?? false
            }
        }

        placeResults = filtered
    }

    func searchPlaces(modelContext: ModelContext) async {
        guard let coordinate = currentCoordinate else {
            errorMessage = "Location not available. Please enable location services."
            requestLocation()
            return
        }

        isLoading = true
        errorMessage = nil

        var keyword = selectedCategory == .all ? "point of interest" : (selectedCategory.searchKeyword ?? "point of interest")
        if !searchText.isEmpty {
            keyword = searchText
        }

        let latitude = coordinate.latitude
        let longitude = coordinate.longitude

        let urlString = "https://nominatim.openstreetmap.org/search?q=\(keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword)&format=json&limit=20&lat=\(latitude)&lon=\(longitude)&bounded=1&addressdetails=1"
        guard let url = URL(string: urlString) else {
            isLoading = false
            errorMessage = "Invalid search URL"
            return
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("SummerCal/2.0", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await URLSession.shared.data(for: request)

            guard let results = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                isLoading = false
                errorMessage = "Unexpected response format"
                return
            }

            var fetched: [PlaceCandidate] = []
            for item in results {
                guard let name = item["display_name"] as? String else { continue }
                let shortName = name.components(separatedBy: ",").first?.trimmingCharacters(in: .whitespaces) ?? name
                let lat = Double(item["lat"] as? String ?? "") ?? 0
                let lon = Double(item["lon"] as? String ?? "") ?? 0

                let categoryName = (item["type"] as? String) ?? item["category"] as? String

                let placeLoc = CLLocation(latitude: lat, longitude: lon)
                let currentLoc = CLLocation(latitude: latitude, longitude: longitude)
                let distance = placeLoc.distance(from: currentLoc)

                let place = PlaceCandidate(
                    name: shortName,
                    category: categoryName,
                    address: name,
                    latitude: lat,
                    longitude: lon,
                    openNow: nil,
                    rating: nil,
                    distanceMeters: distance
                )
                fetched.append(place)

                if let idx = savedPlaces.firstIndex(where: { $0.id == place.id }) {
                    continue
                }
                modelContext.insert(place)
            }
            try? modelContext.save()

            placeResults = fetched
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func deletePlace(_ place: PlaceCandidate, modelContext: ModelContext) {
        modelContext.delete(place)
        try? modelContext.save()
        savedPlaces.removeAll { $0.id == place.id }
        placeResults.removeAll { $0.id == place.id }
    }

    func formattedDistance(_ distanceMeters: Double?) -> String {
        guard let distance = distanceMeters else { return "" }
        if distance < 1000 {
            return String(format: "%.0f m", distance)
        }
        return String(format: "%.1f km", distance / 1000)
    }

    func categoryIcon(for category: String?) -> String {
        guard let cat = category?.lowercased() else { return "mappin" }
        if cat.contains("cafe") || cat.contains("coffee") { return "cup.and.saucer.fill" }
        if cat.contains("restaurant") || cat.contains("food") { return "fork.knife" }
        if cat.contains("park") || cat.contains("garden") { return "leaf.fill" }
        if cat.contains("museum") || cat.contains("gallery") { return "building.columns.fill" }
        if cat.contains("gym") || cat.contains("fitness") { return "dumbbell.fill" }
        if cat.contains("shop") || cat.contains("store") { return "bag.fill" }
        if cat.contains("hotel") || cat.contains("lodging") { return "bed.double.fill" }
        return "mappin"
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationAuthorizationStatus = manager.authorizationStatus
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            currentLocationName = nil
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
            self?.currentLocationName = placemarks?.first?.locality ?? placemarks?.first?.name
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = "Failed to get location: \(error.localizedDescription)"
    }
}
