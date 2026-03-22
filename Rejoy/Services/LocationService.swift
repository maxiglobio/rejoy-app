import Foundation
import CoreLocation

@MainActor
final class LocationService: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()

    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var savedPlaces: [SavedPlace] = []
    @Published var currentPlaceTime: [String: Double] = [:]

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 100
        authorizationStatus = locationManager.authorizationStatus
        loadSavedPlaces()
    }

    func requestAuthorization() async -> Bool {
        locationManager.requestWhenInUseAuthorization()
        // Wait a moment for status update
        try? await Task.sleep(nanoseconds: 500_000_000)
        return locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways
    }

    func saveCurrentLocation(as name: String) {
        guard let loc = locationManager.location else { return }
        let place = SavedPlace(name: name, latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude, id: UUID())
        if let idx = savedPlaces.firstIndex(where: { $0.name == name }) {
            savedPlaces[idx] = place
        } else {
            savedPlaces.append(place)
        }
        savePlacesToStorage()
    }

    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    private func loadSavedPlaces() {
        if let data = UserDefaults.standard.data(forKey: "RejoySavedPlaces"),
           let decoded = try? JSONDecoder().decode([SavedPlace].self, from: data) {
            savedPlaces = decoded
        }
    }

    private func savePlacesToStorage() {
        if let data = try? JSONEncoder().encode(savedPlaces) {
            UserDefaults.standard.set(data, forKey: "RejoySavedPlaces")
        }
    }

    func checkProximity(to location: CLLocation) {
        for place in savedPlaces {
            let placeLocation = CLLocation(latitude: place.latitude, longitude: place.longitude)
            let distance = location.distance(from: placeLocation)
            if distance < 100 {
                // At place - would need to track time; for MVP we use manual buttons
                break
            }
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            checkProximity(to: loc)
        }
    }
}

struct SavedPlace: Codable, Identifiable {
    var id: UUID
    let name: String
    let latitude: Double
    let longitude: Double

    init(name: String, latitude: Double, longitude: Double, id: UUID = UUID()) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        latitude = try c.decode(Double.self, forKey: .latitude)
        longitude = try c.decode(Double.self, forKey: .longitude)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude
    }
}
