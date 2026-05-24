import SwiftUI
import GoogleMaps

struct GoogleMapView: UIViewRepresentable {
    @Binding var places: [PlaceCandidate]
    var currentCoordinate: CLLocationCoordinate2D?
    var selectedMapStyle: PlacesViewModel.MapStyleOption
    var onPlaceTapped: ((PlaceCandidate) -> Void)?
    var onCameraIdle: ((CLLocationCoordinate2D) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> GMSMapView {
        let options = GMSMapViewOptions()
        if let coord = currentCoordinate {
            options.camera = GMSCameraPosition(latitude: coord.latitude, longitude: coord.longitude, zoom: 14)
        } else {
            options.camera = GMSCameraPosition(latitude: 47.4979, longitude: 19.0402, zoom: 6)
        }
        let mapView = GMSMapView(options: options)
        mapView.delegate = context.coordinator
        mapView.isMyLocationEnabled = true
        mapView.settings.myLocationButton = true
        mapView.settings.compassButton = true
        applyStyle(mapView)
        updateMarkers(on: mapView)
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        applyStyle(mapView)
        if let coord = currentCoordinate, context.coordinator.shouldAnimateToUser {
            context.coordinator.shouldAnimateToUser = false
            mapView.animate(to: GMSCameraPosition(latitude: coord.latitude, longitude: coord.longitude, zoom: 14))
        }
        if context.coordinator.placesHash != placesHash {
            context.coordinator.placesHash = placesHash
            updateMarkers(on: mapView)
        }
        if let coord = currentCoordinate {
            context.coordinator.updateUserMarker(at: coord, on: mapView)
        }
    }

    private var placesHash: Int {
        var hasher = Hasher()
        for p in places { hasher.combine(p.id); hasher.combine(p.latitude); hasher.combine(p.longitude) }
        return hasher.finalize()
    }

    private func applyStyle(_ mapView: GMSMapView) {
        switch selectedMapStyle {
        case .satellite: mapView.mapType = .satellite
        case .hybrid:    mapView.mapType = .hybrid
        default:         mapView.mapType = .normal
        }
    }

    private func updateMarkers(on mapView: GMSMapView) {
        mapView.clear()
        for place in places {
            let marker = GMSMarker()
            marker.position = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
            marker.title = place.name
            marker.snippet = place.address
            marker.userData = place.id.uuidString
            if let rating = place.rating {
                marker.icon = markerIcon(color: ratingColor(rating))
            } else {
                marker.icon = markerIcon(color: .orange)
            }
            marker.map = mapView
        }
    }

    private func ratingColor(_ rating: Double) -> UIColor {
        if rating >= 4.0 { return .systemGreen }
        if rating >= 3.0 { return .orange }
        return .systemGray
    }

    private func markerIcon(color: UIColor) -> UIImage {
        let size = CGSize(width: 30, height: 30)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return UIImage() }
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: CGRect(x: 0, y: 0, width: 30, height: 30))
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.fillEllipse(in: CGRect(x: 8, y: 8, width: 14, height: 14))
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }

    class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: GoogleMapView
        var placesHash: Int = 0
        var shouldAnimateToUser = true
        private var userMarker: GMSMarker?

        init(parent: GoogleMapView) {
            self.parent = parent
        }

        func updateUserMarker(at coordinate: CLLocationCoordinate2D, on mapView: GMSMapView) {
            if userMarker == nil {
                userMarker = GMSMarker()
                userMarker?.icon = GMSMarker.markerImage(with: .blue)
                userMarker?.title = "You"
            }
            userMarker?.position = coordinate
            userMarker?.map = mapView
        }

        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            guard let placeId = marker.userData as? String,
                  let place = parent.places.first(where: { $0.id.uuidString == placeId }) else { return false }
            parent.onPlaceTapped?(place)
            return true
        }

        func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
            parent.onCameraIdle?(position.target)
        }
    }
}
