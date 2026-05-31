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

    func matches(_ place: PlaceCandidate) -> Bool {
        guard self != .all else { return true }

        let searchable = [
            place.category,
            place.name,
            place.address,
            place.vicinity
        ]
        .compactMap { $0?.lowercased() }
        .joined(separator: " ")

        switch self {
        case .all:
            return true
        case .cafe:
            return searchable.contains("cafe") || searchable.contains("coffee")
        case .gym:
            return searchable.contains("gym") || searchable.contains("fitness")
        case .restaurant:
            return searchable.contains("restaurant") || searchable.contains("meal") || searchable.contains("food")
        case .park:
            return searchable.contains("park")
        case .museum:
            return searchable.contains("museum") || searchable.contains("gallery")
        case .shop:
            return searchable.contains("shop") || searchable.contains("store") || searchable.contains("mall")
        case .errand:
            return searchable.contains("errand") ||
                searchable.contains("bank") ||
                searchable.contains("pharmacy") ||
                searchable.contains("post_office") ||
                searchable.contains("laundry") ||
                searchable.contains("gas_station") ||
                searchable.contains("local_government_office")
        }
    }
}

@Observable
final class PlacesViewModel: NSObject, CLLocationManagerDelegate {
    var searchText: String = ""
    var selectedCategory: PlaceCategory = .all
    var isMapView: Bool = true
    var placeResults: [PlaceCandidate] = []
    var savedPlaces: [PlaceCandidate] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var locationAuthorizationStatus: CLAuthorizationStatus = .notDetermined
    var currentLocationName: String?
    var selectedMapStyle: MapStyleOption = .standard

    enum MapStyleOption: String, CaseIterable, Identifiable {
        case standard, satellite, hybrid
        var id: String { rawValue }
        var label: String {
            switch self {
            case .standard: return "Standard"
            case .satellite: return "Satellite"
            case .hybrid: return "Hybrid"
            }
        }
        var icon: String {
            switch self {
            case .standard: return "map"
            case .satellite: return "globe"
            case .hybrid: return "map.fill"
            }
        }
    }

    private let locationManager = CLLocationManager()
    var currentCoordinate: CLLocationCoordinate2D?
    private var placesService: PlacesService?
    private var hasInitialLocation = false

    var placesProviderName: String {
        placesService?.providerName ?? "Apple MapKit"
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func configurePlacesService(with googleApiKey: String?) {
        // Only create once and re-create if key changes
        if placesService == nil || googleApiKey != nil {
            placesService = PlacesService(googleApiKey: googleApiKey)
        }
    }

    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
    }

    func loadSavedPlaces(modelContext: ModelContext) {
        let settings = UserSettings.current(in: modelContext)
        configurePlacesService(with: settings.googlePlacesAPIKey)

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
                selectedCategory.matches($0) || ($0.category?.lowercased().contains(keyword) ?? false)
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

        let categoryKeyword = selectedCategory == .all ? "point of interest" : (selectedCategory.searchKeyword ?? "point of interest")
        var keyword = categoryKeyword
        if !searchText.isEmpty {
            keyword = selectedCategory == .all ? searchText : "\(searchText) \(categoryKeyword)"
        }

        let coord = Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)

        // Use PlacesService (Google/MapKit) instead of Nominatim
        guard let service = placesService else {
            isLoading = false
            errorMessage = "Search service not configured"
            return
        }

        await service.searchNearby(query: keyword, coordinate: coord, radiusMeters: 5000)

        await MainActor.run {
            if service.error != nil {
                errorMessage = service.error
            }
            let fetched = filteredForCurrentSelection(service.results)
            if fetched.isEmpty && !searchText.isEmpty {
                applyFilters()
                isLoading = false
                return
            }
            // Save newly fetched places
            for place in fetched {
                if !savedPlaces.contains(where: { $0.placeId == place.placeId && place.placeId != nil }) {
                    modelContext.insert(place)
                }
            }
            try? modelContext.save()

            savedPlaces = mergedUniquePlaces(fetched + savedPlaces)
            applyFilters()
            isLoading = false
        }
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

    private func filteredForCurrentSelection(_ places: [PlaceCandidate]) -> [PlaceCandidate] {
        var filtered = places
        if selectedCategory != .all {
            filtered = filtered.filter { selectedCategory.matches($0) }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            filtered = filtered.filter {
                $0.name.lowercased().contains(query) ||
                ($0.address?.lowercased().contains(query) ?? false) ||
                ($0.category?.lowercased().contains(query) ?? false) ||
                ($0.vicinity?.lowercased().contains(query) ?? false)
            }
        }
        return filtered
    }

    private func mergedUniquePlaces(_ places: [PlaceCandidate]) -> [PlaceCandidate] {
        var seen = Set<String>()
        var merged: [PlaceCandidate] = []

        for place in places {
            let key = place.placeId ?? "\(place.name.lowercased())|\(place.latitude)|\(place.longitude)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            merged.append(place)
        }

        return merged
    }

    // MARK: - CLLocationManagerDelegate

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

        // Only stop after first fix to avoid battery drain — restart if map view is active
        if !hasInitialLocation {
            hasInitialLocation = true
            manager.stopUpdatingLocation()
        }
        if isMapView && hasInitialLocation {
            // Keep updating in map mode, but throttle
            manager.distanceFilter = 100
        }

        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            self?.currentLocationName = placemarks?.first?.locality ?? placemarks?.first?.name
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = "Failed to get location: \(error.localizedDescription)"
    }
}
