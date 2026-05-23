import SwiftUI
import SwiftData
import MapKit

struct PlacesView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = PlacesViewModel()
    @State private var selectedPlace: PlaceCandidate?
    @State private var showDetail: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            searchAndFilterBar

            if viewModel.isMapView {
                mapContent
            } else {
                if viewModel.locationAuthorizationStatus == .denied || viewModel.locationAuthorizationStatus == .restricted {
                    locationDeniedView
                }

                if viewModel.isLoading {
                    ProgressView("Searching...")
                        .padding()
                }

                if let error = viewModel.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }

                placesList
            }
        }
        .navigationTitle("Places")
        .onAppear {
            viewModel.requestLocation()
            viewModel.loadSavedPlaces(modelContext: modelContext)
        }
        .onChange(of: viewModel.selectedCategory) { _, _ in
            viewModel.applyFilters()
        }
        .onChange(of: viewModel.searchText) { _, _ in
            viewModel.applyFilters()
        }
        .sheet(isPresented: $showDetail) {
            if let place = selectedPlace {
                placeDetailSheet(place)
            }
        }
    }

    private var searchAndFilterBar: some View {
        VStack(spacing: 8) {
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search places...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            Task { await viewModel.searchPlaces(modelContext: modelContext) }
                        }
                }
                .padding(8)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))

                Picker("View", selection: $viewModel.isMapView) {
                    Label("List", systemImage: "list.bullet").tag(false)
                    Label("Map", systemImage: "map").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PlaceCategory.allCases) { category in
                        Button {
                            viewModel.selectedCategory = category
                            Task { await viewModel.searchPlaces(modelContext: modelContext) }
                        } label: {
                            Label(category.label, systemImage: category.icon)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(viewModel.selectedCategory == category ? .orange : Color(.systemGray6))
                                .foregroundStyle(viewModel.selectedCategory == category ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            if let locationName = viewModel.currentLocationName {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text(locationName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }

    private var mapContent: some View {
        Map {
            ForEach(viewModel.placeResults) { place in
                Marker(place.name, coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude))
                    .tint(.orange)
            }
            if let coord = CLLocationManager().location?.coordinate {
                Marker("You", systemImage: "person.circle.fill", coordinate: coord)
            }
        }
        .mapStyle(.standard)
    }

    private var locationDeniedView: some View {
        HStack(spacing: 8) {
            Image(systemName: "location.slash")
                .foregroundColor(.orange)
            VStack(alignment: .leading) {
                Text("Location access needed")
                    .font(.caption)
                    .fontWeight(.semibold)
                Text("Enable location in Settings to find nearby places.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .tint(.orange)
        }
        .padding(12)
        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var placesList: some View {
        List {
            if viewModel.placeResults.isEmpty && !viewModel.isLoading {
                Section {
                    ContentUnavailableView(
                        "No Places Found",
                        systemImage: "mappin.slash",
                        description: Text("Try adjusting your search or category filters.")
                    )
                }
            } else {
                ForEach(viewModel.placeResults) { place in
                    placeRow(place)
                        .onTapGesture {
                            selectedPlace = place
                            showDetail = true
                        }
                }
                .onDelete { offsets in
                    for idx in offsets {
                        let place = viewModel.placeResults[idx]
                        viewModel.deletePlace(place, modelContext: modelContext)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func placeRow(_ place: PlaceCandidate) -> some View {
        HStack(spacing: 12) {
            Image(systemName: viewModel.categoryIcon(for: place.category))
                .font(.title3)
                .frame(width: 36, height: 36)
                .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)

                if let address = place.address {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    if let open = place.openNow {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(open ? Color.green : Color.red)
                                .frame(width: 6, height: 6)
                            Text(open ? "Open" : "Closed")
                                .font(.caption2)
                                .foregroundStyle(open ? .green : .red)
                        }
                    }

                    if let rating = place.rating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", rating))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            if let distance = place.distanceMeters {
                Text(viewModel.formattedDistance(distance))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6), in: Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    private func placeDetailSheet(_ place: PlaceCandidate) -> some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: viewModel.categoryIcon(for: place.category))
                                .font(.title)
                                .foregroundColor(.orange)
                            Text(place.name)
                                .font(.title3)
                                .fontWeight(.bold)
                        }

                        if let category = place.category {
                            Text(category.capitalized)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.orange.opacity(0.1), in: Capsule())
                        }

                        if let address = place.address {
                            Label(address, systemImage: "mappin.and.ellipse")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if let distance = place.distanceMeters {
                            Label(viewModel.formattedDistance(distance), systemImage: "figure.walk")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if let rating = place.rating {
                            Label(String(format: "%.1f / 5.0", rating), systemImage: "star.fill")
                                .font(.subheadline)
                                .foregroundColor(.yellow)
                        }
                    }
                }

                Section {
                    if let address = place.address {
                        Button {
                            openInMaps(place)
                        } label: {
                            Label("Open in Maps", systemImage: "map")
                        }
                    }

                    Button {
                        UIPasteboard.general.string = place.address ?? place.name
                    } label: {
                        Label("Copy Address", systemImage: "doc.on.doc")
                    }
                }

                Section {
                    Button {
                        let lat = place.latitude
                        let lon = place.longitude
                        if let url = URL(string: "http://maps.apple.com/?ll=\(lat),\(lon)&q=\(place.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? place.name)") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Get Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    }
                }
            }
            .navigationTitle("Place Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showDetail = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func openInMaps(_ place: PlaceCandidate) {
        let coordinate = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = place.name
        mapItem.openInMaps()
    }
}
