import Foundation
import CoreLocation
import SwiftData

@Observable
final class LocationService: NSObject {
    static let shared = LocationService()

    private let locationManager = CLLocationManager()
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var currentLocation: CLLocation?
    private(set) var currentPlaceName: String?
    private(set) var placeArrivalTime: Date?

    // Track dwell times for places
    private(set) var dwellLog: [DwellEntry] = []

    override init() {
        super.init()
        locationManager.delegate = self

        // Battery-conscious settings:
        // - hundredMeters is sufficient for place detection (home/work/gym)
        // - pausesLocationUpdatesAutomatically lets iOS suspend updates when stationary
        // - NO continuous GPS — we rely on significant location changes + CLVisit + geofencing
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.allowsBackgroundLocationUpdates = false

        authorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - Authorization

    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    // MARK: - Monitoring (battery-efficient: significant changes + visits only)

    /// Start passive location monitoring. This does NOT use continuous GPS.
    /// - Significant location changes: wakes the app on cell-tower-level moves (~500m+)
    /// - Visit monitoring: iOS detects dwell time at locations automatically (CLVisit)
    /// Both are extremely battery-efficient — iOS manages the hardware.
    func startMonitoring() {
        guard isAuthorized else { return }
        locationManager.startMonitoringSignificantLocationChanges()
        locationManager.startMonitoringVisits()
    }

    func stopMonitoring() {
        locationManager.stopMonitoringSignificantLocationChanges()
        locationManager.stopMonitoringVisits()
    }

    // MARK: - Geofencing (up to 20 regions, hardware-managed, zero battery cost when idle)

    func startMonitoringPlace(_ place: LocationPlace) {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else { return }

        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
            radius: place.radiusMeters,
            identifier: place.id.uuidString
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true
        locationManager.startMonitoring(for: region)
    }

    func stopMonitoringPlace(_ place: LocationPlace) {
        let region = locationManager.monitoredRegions.first { $0.identifier == place.id.uuidString }
        if let region = region {
            locationManager.stopMonitoring(for: region)
        }
    }

    func startMonitoringAllPlaces(context: ModelContext) {
        let descriptor = FetchDescriptor<LocationPlace>()
        guard let places = try? context.fetch(descriptor) else { return }
        for place in places {
            startMonitoringPlace(place)
        }
    }

    // MARK: - Current Place Detection (geofence-based)

    /// Returns the place the user is currently inside, based on geofence state.
    /// Falls back to distance check against last known location.
    func currentPlace(context: ModelContext) -> LocationPlace? {
        // First: check if a geofence region is active
        if let activePlaceID = currentPlaceName,
           let uuid = UUID(uuidString: activePlaceID) {
            let descriptor = FetchDescriptor<LocationPlace>()
            if let places = try? context.fetch(descriptor),
               let match = places.first(where: { $0.id == uuid }) {
                return match
            }
        }

        // Fallback: distance check against last known location
        guard let location = lastKnownLocation else { return nil }

        let descriptor = FetchDescriptor<LocationPlace>()
        guard let places = try? context.fetch(descriptor) else { return nil }

        for place in places {
            let placeLocation = CLLocation(latitude: place.latitude, longitude: place.longitude)
            let distance = location.distance(from: placeLocation)
            if distance <= place.radiusMeters {
                return place
            }
        }
        return nil
    }

    // MARK: - One-shot Location Request (async, foreground only)

    /// Last known location (updated by significant changes, visits, or one-shot requests)
    private(set) var lastKnownLocation: CLLocation?

    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    /// Request a single location fix. Returns nil if unavailable.
    func requestCurrentLocation() async -> CLLocation? {
        guard isAuthorized else { return nil }
        return await withCheckedContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()
        }
    }

    // MARK: - Dwell Time

    func fetchDwellTimes(for date: Date, context: ModelContext) -> [DwellEntry] {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        return dwellLog.filter { entry in
            entry.arrivalDate >= startOfDay && entry.arrivalDate < endOfDay
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
        lastKnownLocation = locations.last
        if let continuation = locationContinuation {
            locationContinuation = nil
            continuation.resume(returning: locations.last)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let continuation = locationContinuation {
            locationContinuation = nil
            continuation.resume(returning: nil)
        }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circular = region as? CLCircularRegion else { return }
        currentPlaceName = circular.identifier
        placeArrivalTime = Date()
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let circular = region as? CLCircularRegion else { return }

        if let arrival = placeArrivalTime, circular.identifier == currentPlaceName {
            let entry = DwellEntry(
                placeID: circular.identifier,
                arrivalDate: arrival,
                departureDate: Date()
            )
            dwellLog.append(entry)
        }

        if circular.identifier == currentPlaceName {
            currentPlaceName = nil
            placeArrivalTime = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        // CLVisit: iOS automatically detects when the user stays at a location.
        // Arrival/departure are provided after the fact — extremely battery efficient.
        guard visit.departureDate != .distantFuture else { return }

        let entry = DwellEntry(
            placeID: "visit_\(visit.coordinate.latitude)_\(visit.coordinate.longitude)",
            arrivalDate: visit.arrivalDate,
            departureDate: visit.departureDate
        )
        dwellLog.append(entry)
    }
}

// MARK: - Supporting Types

struct DwellEntry {
    let placeID: String
    let arrivalDate: Date
    let departureDate: Date

    var durationMinutes: Int {
        Int(departureDate.timeIntervalSince(arrivalDate) / 60)
    }
}
