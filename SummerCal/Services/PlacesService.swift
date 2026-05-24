import Foundation
import MapKit
import CoreLocation

struct Coordinate: Codable, Equatable {
    var latitude: Double
    var longitude: Double

    var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct PlaceDetails: Codable {
    var placeId: String
    var name: String
    var address: String?
    var phoneNumber: String?
    var websiteURL: String?
    var openNow: Bool?
    var rating: Double?
}

protocol PlacesProvider {
    func searchNearby(query: String, coordinate: Coordinate, radiusMeters: Double) async throws -> [PlaceCandidate]
    func details(placeId: String) async throws -> PlaceDetails
}

final class MapKitPlacesProvider: PlacesProvider {
    func searchNearby(query: String, coordinate: Coordinate, radiusMeters: Double) async throws -> [PlaceCandidate] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: coordinate.clLocationCoordinate,
            latitudinalMeters: radiusMeters,
            longitudinalMeters: radiusMeters
        )

        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return response.mapItems.map { item in
            let distance = item.placemark.location.map { $0.distance(from: origin) } ?? 0
            let address = [item.placemark.thoroughfare, item.placemark.locality,
                           item.placemark.administrativeArea, item.placemark.postalCode,
                           item.placemark.country].compactMap { $0 }.joined(separator: ", ")
            return PlaceCandidate(
                name: item.name ?? "Unknown",
                category: item.pointOfInterestCategory?.rawValue ?? "place",
                address: address,
                latitude: item.placemark.coordinate.latitude,
                longitude: item.placemark.coordinate.longitude,
                rating: nil,
                placeId: item.placemark.name ?? UUID().uuidString,
                distanceMeters: distance
            )
        }
    }

    func details(placeId: String) async throws -> PlaceDetails {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = placeId

        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        guard let item = response.mapItems.first else {
            throw NSError(domain: "Places", code: 404, userInfo: [NSLocalizedDescriptionKey: "Place not found"])
        }

        let address = [item.placemark.thoroughfare, item.placemark.locality,
                       item.placemark.administrativeArea, item.placemark.postalCode,
                       item.placemark.country].compactMap { $0 }.joined(separator: ", ")

        return PlaceDetails(
            placeId: placeId,
            name: item.name ?? "Unknown",
            address: address,
            phoneNumber: item.phoneNumber,
            websiteURL: item.url?.absoluteString,
            openNow: nil,
            rating: nil
        )
    }
}

final class GooglePlacesProvider: PlacesProvider {
    private let apiKey: String
    private let baseURL = "https://maps.googleapis.com/maps/api/place"

    init(apiKey: String) { self.apiKey = apiKey }

    func searchNearby(query: String, coordinate: Coordinate, radiusMeters: Double) async throws -> [PlaceCandidate] {
        guard !apiKey.isEmpty else { return [] }

        var components = URLComponents(string: "\(baseURL)/nearbysearch/json")!
        components.queryItems = [
            URLQueryItem(name: "location", value: "\(coordinate.latitude),\(coordinate.longitude)"),
            URLQueryItem(name: "radius", value: String(Int(radiusMeters))),
            URLQueryItem(name: "keyword", value: query),
            URLQueryItem(name: "key", value: apiKey)
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let rawResults = json?["results"] as? [[String: Any]] ?? []

        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        let candidates: [PlaceCandidate] = rawResults.compactMap { place in
            guard let name = place["name"] as? String,
                  let geometry = place["geometry"] as? [String: Any],
                  let location = geometry["location"] as? [String: Any],
                  let lat = location["lat"] as? Double,
                  let lng = location["lng"] as? Double,
                  let placeId = place["place_id"] as? String else { return nil }

            let openingHours = place["opening_hours"] as? [String: Any]
            let openNow = openingHours?["open_now"] as? Bool
            let rating = place["rating"] as? Double
            let vicinity = place["vicinity"] as? String
            let types = place["types"] as? [String] ?? []
            let category = types.first
            let photoReference = (place["photos"] as? [[String: Any]])?.first?["photo_reference"] as? String
            let placeLoc = CLLocation(latitude: lat, longitude: lng)

            return PlaceCandidate(
                name: name,
                category: category,
                address: vicinity,
                latitude: lat,
                longitude: lng,
                openNow: openNow,
                rating: rating,
                placeId: placeId,
                distanceMeters: origin.distance(from: placeLoc),
                photoReference: photoReference,
                vicinity: vicinity
            )
        }

        return candidates.sorted { ($0.distanceMeters ?? .infinity) < ($1.distanceMeters ?? .infinity) }
    }

    func details(placeId: String) async throws -> PlaceDetails {
        var components = URLComponents(string: "\(baseURL)/details/json")!
        components.queryItems = [
            URLQueryItem(name: "place_id", value: placeId),
            URLQueryItem(name: "fields", value: "name,formatted_address,formatted_phone_number,website,opening_hours,rating,photos"),
            URLQueryItem(name: "key", value: apiKey)
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let result = json?["result"] as? [String: Any]

        guard let name = result?["name"] as? String else {
            throw NSError(domain: "Places", code: 404, userInfo: [NSLocalizedDescriptionKey: "Place not found"])
        }

        let openingHours = result?["opening_hours"] as? [String: Any]

        return PlaceDetails(
            placeId: placeId,
            name: name,
            address: result?["formatted_address"] as? String,
            phoneNumber: result?["formatted_phone_number"] as? String,
            websiteURL: result?["website"] as? String,
            openNow: openingHours?["open_now"] as? Bool,
            rating: result?["rating"] as? Double
        )
    }
}

final class PlacesService: ObservableObject {
    private let googleApiKey: String?
    private let mapKitProvider: MapKitPlacesProvider
    private var googleProvider: GooglePlacesProvider?

    @Published var isLoading = false
    @Published var results: [PlaceCandidate] = []
    @Published var error: String?

    /// Creates a PlacesService. Google API key should come from UserSettings — never hardcoded.
    init(googleApiKey: String?) {
        self.googleApiKey = (googleApiKey?.isEmpty == false) ? googleApiKey : nil
        self.mapKitProvider = MapKitPlacesProvider()
        if let key = self.googleApiKey, !key.isEmpty {
            self.googleProvider = GooglePlacesProvider(apiKey: key)
        }
    }

    func searchNearby(query: String, coordinate: Coordinate, radiusMeters: Double = 3000) async {
        await MainActor.run { isLoading = true; error = nil }
        do {
            let candidates = try await resolveProvider().searchNearby(query: query, coordinate: coordinate, radiusMeters: radiusMeters)
            await MainActor.run { results = candidates; isLoading = false }
        } catch {
            if let _ = googleApiKey {
                do {
                    let fallback = try await mapKitProvider.searchNearby(query: query, coordinate: coordinate, radiusMeters: radiusMeters)
                    await MainActor.run { results = fallback; isLoading = false }
                    return
                } catch {
                    await MainActor.run { self.error = error.localizedDescription; isLoading = false }
                }
            } else {
                await MainActor.run { self.error = error.localizedDescription; isLoading = false }
            }
        }
    }

    func searchNearbyWithGoogle(query: String, coordinate: Coordinate, radiusMeters: Double = 5000) async throws -> [PlaceCandidate] {
        guard let google = googleProvider else {
            throw NSError(domain: "PlacesService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Google API key not configured"])
        }
        return try await google.searchNearby(query: query, coordinate: coordinate, radiusMeters: radiusMeters)
    }

    func openNowCandidates(for query: String, location: Coordinate) async throws -> [PlaceCandidate] {
        let candidates = try await resolveProvider().searchNearby(query: query, coordinate: location, radiusMeters: 3000)
        if googleProvider != nil {
            return candidates.filter { $0.openNow != false }
        }
        return candidates
    }

    func placeDetails(placeId: String) async throws -> PlaceDetails {
        try await resolveProvider().details(placeId: placeId)
    }

    func hasGoogleProvider() -> Bool {
        googleProvider != nil
    }

    func popularCategories() -> [String] {
        ["cafe", "gym", "restaurant", "park", "museum", "shopping", "errand"]
    }

    private func resolveProvider() -> PlacesProvider {
        googleProvider ?? mapKitProvider
    }
}
