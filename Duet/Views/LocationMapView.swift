import SwiftUI
import MapKit
import CoreLocation

/// Conform CLLocationCoordinate2D to Equatable for onChange support
extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

/// A SwiftUI view that displays a map with a pin for a given location string.
/// Supports specific addresses, cities, countries, or regions.
struct LocationMapView: View {
    let location: String
    let height: CGFloat
    let hideOnFailure: Bool
    
    @StateObject private var viewModel = LocationMapViewModel()
    @State private var cameraPosition = MapCameraPosition.automatic
    @State private var didSetInitialPosition = false
    
    public init(location: String, height: CGFloat = 200, hideOnFailure: Bool = false) {
        self.location = location
        self.height = height
        self.hideOnFailure = hideOnFailure
    }

        var body: some View {
        Group {
            if hideOnFailure && viewModel.hasFailedToLoad {
                EmptyView()
            } else {
                mapContent
            }
        }
        .onAppear {
            viewModel.fetchLocation(location)
        }
        .onChange(of: location) { old, new in
            didSetInitialPosition = false
            viewModel.fetchLocation(new)
        }
    }
    
    private var mapContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            ZStack {
                if viewModel.isLoading {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: height)
                        .overlay(
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Loading map...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        )
                } else if let coordinate = viewModel.coordinate {
                    Map(position: $cameraPosition) {
                        Marker(viewModel.displayName ?? location, coordinate: coordinate)
                            .tint(Color.appPrimary)
                    }
                    .frame(height: height)
                    .cornerRadius(12)
                    .allowsHitTesting(true)
                    .onAppear {
                        setCamera(to: coordinate, span: viewModel.span)
                    }
                    .onChange(of: viewModel.coordinate) { old, new in
                        guard let newCoord = new, !didSetInitialPosition else { return }
                        setCamera(to: newCoord, span: viewModel.span)
                        didSetInitialPosition = true
                    }
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: height)
                        .overlay(
                            VStack(spacing: 4) {
                                Image(systemName: "mappin.slash")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                                Text("Unable to load map")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(location)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .multilineTextAlignment(.center)
                            }
                        )
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
        }
    }

    private func setCamera(to coordinate: CLLocationCoordinate2D, span: MKCoordinateSpan) {
        let region = MKCoordinateRegion(center: coordinate, span: span)
        cameraPosition = .region(region)
    }
}

// MARK: - View Model

final class LocationMapViewModel: ObservableObject {
    @Published var coordinate: CLLocationCoordinate2D?
    @Published var displayName: String?
    @Published var isLoading = false
    @Published var hasFailedToLoad = false
    var span = MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360)

    private let geocoder = CLGeocoder()
    private var currentLocationString = ""

    func fetchLocation(_ address: String) {
        guard !address.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        currentLocationString = address
        isLoading = true
        coordinate = nil
        displayName = nil
        hasFailedToLoad = false

        Task {
            do {
                let placemarks = try await geocoder.geocodeAddressString(address)
                if let placemark = placemarks.first, let loc = placemark.location {
                    await MainActor.run {
                        coordinate = loc.coordinate
                        displayName = formatLocationName(from: placemark)
                        span = span(for: placemark)
                        isLoading = false
                        hasFailedToLoad = false
                    }
                } else {
                    await MainActor.run { 
                        isLoading = false
                        hasFailedToLoad = true
                    }
                }
            } catch {
                await MainActor.run { 
                    isLoading = false
                    hasFailedToLoad = true
                }
            }
        }
    }

    private func formatLocationName(from placemark: CLPlacemark) -> String {
        // 1) specific POI/street
        if let name = placemark.name, placemark.locality != nil {
            return name
        }
        // 2) city
        if let city = placemark.locality {
            return city
        }
        // 3) state/region
        if let region = placemark.administrativeArea {
            return region
        }
        // 4) country
        if let country = placemark.country {
            return country
        }
        // fallback
        return currentLocationString
    }

    private func span(for placemark: CLPlacemark) -> MKCoordinateSpan {
        // More granular zoom levels based on location specificity
        
        // 1. Street address or specific POI (most zoomed in)
        if placemark.thoroughfare != nil || (placemark.name != nil && placemark.subLocality != nil) {
            return MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        }
        
        // 2. Neighborhood/suburb (like Pimlico)
        if placemark.subLocality != nil || (placemark.name != nil && placemark.locality != nil && placemark.name != placemark.locality) {
            return MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        }
        
        // 3. City level
        if placemark.locality != nil {
            return MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        }
        
        // 4. State/region level
        if placemark.administrativeArea != nil {
            return MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
        }
        
        // 5. Country level (most zoomed out)
        if placemark.country != nil {
            return MKCoordinateSpan(latitudeDelta: 8.0, longitudeDelta: 8.0)
        }
        
        // Fallback for unknown locations
        return MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    }
}

struct MapPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let title: String
}

#Preview {
    VStack(spacing: 20) {
        LocationMapView(location: "Central Park, NYC")
        LocationMapView(location: "Singapore", height: 150)
        LocationMapView(location: "Invalid location", hideOnFailure: false)
        LocationMapView(location: "Raja Ampat, indonesia", height: 120)
    }
    .padding()
} 
