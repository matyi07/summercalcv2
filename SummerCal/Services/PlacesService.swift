import Foundation
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

final class GooglePlacesProvider: PlacesProvider {
    private let apiKey: String
    private let baseURL = "https://maps.googleapis.com/maps/api/place"

    init(apiKey: String) { self.apiKey = apiKey }

    func searchNearby(query: String, coordinate: Coordinate, radiusMeters: Double) async throws -> [PlaceCandidate] {
        guard !apiKey.isEmpty else { throw placesError(0, "Google API key not configured") }

        var components = URLComponents(string: "\(baseURL)/nearbysearch/json")!
        components.queryItems = [
            URLQueryItem(name: "location", value: "\(coordinate.latitude),\(coordinate.longitude)"),
            URLQueryItem(name: "radius", value: String(Int(radiusMeters))),
            URLQueryItem(name: "keyword", value: query),
            URLQueryItem(name: "key", value: apiKey)
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        if let status = json?["status"] as? String, status != "OK" && status != "ZERO_RESULTS" {
            let errorMsg = json?["error_message"] as? String ?? "Google Places error: \(status)"
            throw placesError(400, errorMsg)
        }

        let rawResults = json?["results"] as? [[String: Any]] ?? []
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        return rawResults.compactMap { place in
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
        }.sorted { ($0.distanceMeters ?? .infinity) < ($1.distanceMeters ?? .infinity) }
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
            throw placesError(404, "Place not found")
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
    private let googleProvider: GooglePlacesProvider

    @Published var isLoading = false
    @Published var results: [PlaceCandidate] = []
    @Published var error: String?

    init(googleApiKey: String?) {
        let key = (googleApiKey?.isEmpty == false) ? googleApiKey! : GoogleAPI.defaultKey
        self.googleProvider = GooglePlacesProvider(apiKey: key)
    }

    func searchNearby(query: String, coordinate: Coordinate, radiusMeters: Double = 3000) async {
        await MainActor.run { isLoading = true; error = nil }
        do {
            let candidates = try await googleProvider.searchNearby(query: query, coordinate: coordinate, radiusMeters: radiusMeters)
            await MainActor.run { results = candidates; isLoading = false }
        } catch {
            await MainActor.run { error = error.localizedDescription; isLoading = false }
        }
    }

    func searchNearbyWithGoogle(query: String, coordinate: Coordinate, radiusMeters: Double = 5000) async throws -> [PlaceCandidate] {
        try await googleProvider.searchNearby(query: query, coordinate: coordinate, radiusMeters: radiusMeters)
    }

    func placeDetails(placeId: String) async throws -> PlaceDetails {
        try await googleProvider.details(placeId: placeId)
    }

    var providerName: String { "Google Places" }

    func popularCategories() -> [String] {
        ["cafe", "gym", "restaurant", "park", "museum", "shopping", "errand"]
    }
}

private func placesError(_ code: Int, _ message: String) -> Error {
    NSError(domain: "PlacesService", code: code, userInfo: [NSLocalizedDescriptionKey: message])
}

enum GoogleAPI {
    static let defaultKey = "AIzaSyCchq9xvIlpqqkE2bdTUV8kc3ZadXZPVus"
}
