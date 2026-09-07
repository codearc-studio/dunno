import Combine
import CoreLocation
import Foundation
import MapKit
import UIKit

struct DunnoNearbyPlace: Identifiable {
    let id: String
    let name: String
    let distance: CLLocationDistance
    let kind: DunnoNearbyKind
    let mapItem: MKMapItem

    var distanceLabel: String {
        DunnoNearbyService.distanceFormatter.string(fromDistance: distance)
    }
}

@MainActor
final class DunnoNearbyService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let enabledStorageKey = "dunno.settings.nearbyEnabled"
    static let distanceFormatter: MKDistanceFormatter = {
        let formatter = MKDistanceFormatter()
        formatter.unitStyle = .abbreviated
        return formatter
    }()

    @Published private(set) var isEnabled: Bool
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var availableKinds: Set<DunnoNearbyKind> = []
    @Published private(set) var placeResults: [DunnoNearbyKind: [DunnoNearbyPlace]] = [:]
    @Published private(set) var loadingKinds: Set<DunnoNearbyKind> = []
    @Published private(set) var isLocating = false
    @Published private(set) var lastError: String?

    private let defaults: UserDefaults
    private var manager: CLLocationManager!
    private var currentLocation: CLLocation?
    private var lastCommonSearchLocation: CLLocation?
    private var lastCommonSearchDate: Date?
    private var commonSearchTask: Task<Void, Never>?
    private var pendingKinds: Set<DunnoNearbyKind> = []

    private let commonSearchLifetime: TimeInterval = 15 * 60
    private let commonSearchMovementThreshold: CLLocationDistance = 800

    override convenience init() {
        self.init(defaults: .standard)
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        self.isEnabled = defaults.bool(forKey: Self.enabledStorageKey)
        self.authorizationStatus = .notDetermined
        super.init()

        manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var requiresSettings: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    func setEnabled(_ enabled: Bool, requestPermission: Bool = false) {
        guard isEnabled != enabled || requestPermission else { return }

        isEnabled = enabled
        defaults.set(enabled, forKey: Self.enabledStorageKey)
        lastError = nil

        if enabled {
            if requestPermission {
                requestAccessOrRefresh()
            } else if isAuthorized {
                refreshIfAuthorized()
            }
        } else {
            clearSessionLocation()
        }
    }

    /// Call only from a deliberate user action. If Allow Once has expired, this can show
    /// the foreground permission prompt again without surprising someone at app launch.
    func requestAccessOrRefresh() {
        guard isEnabled else {
            setEnabled(true, requestPermission: true)
            return
        }

        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            requestCurrentLocation(force: true)
        case .denied:
            lastError = "Location access is off for Dunno."
        case .restricted:
            lastError = "Location access is restricted on this device."
        @unknown default:
            lastError = "Location isn't available right now."
        }
    }

    /// Safe to call whenever the app becomes active. This never prompts for permission.
    func refreshIfAuthorized(force: Bool = false) {
        let latestStatus = manager.authorizationStatus
        if latestStatus != authorizationStatus {
            authorizationStatus = latestStatus
        }

        guard isEnabled, isAuthorized else { return }

        if !force,
           let location = currentLocation,
           abs(location.timestamp.timeIntervalSinceNow) < commonSearchLifetime {
            refreshCommonKindsIfNeeded(near: location, force: false)
            return
        }

        requestCurrentLocation(force: force)
    }

    func places(for activity: DunnoActivity) -> [DunnoNearbyPlace] {
        guard let kind = DunnoNearbyKind.infer(for: activity) else { return [] }
        return placeResults[kind] ?? []
    }

    func isLoading(_ kind: DunnoNearbyKind) -> Bool {
        loadingKinds.contains(kind) || isLocating
    }

    func loadPlaces(for activity: DunnoActivity, force: Bool = false) async {
        guard isEnabled, isAuthorized,
              let kind = DunnoNearbyKind.infer(for: activity) else { return }

        if currentLocation == nil {
            pendingKinds.insert(kind)
            if !isLocating { requestCurrentLocation(force: force) }
            return
        }

        if !force, placeResults[kind] != nil { return }
        if !force, loadingKinds.contains(kind) { return }
        guard let location = currentLocation else { return }

        await loadAndStore(kind: kind, near: location, force: force)
    }

    private func loadAndStore(
        kind: DunnoNearbyKind,
        near location: CLLocation,
        force: Bool
    ) async {
        if !force, placeResults[kind] != nil { return }
        if !force, loadingKinds.contains(kind) { return }

        loadingKinds.insert(kind)
        defer { loadingKinds.remove(kind) }

        let places = await search(kind: kind, near: location)
        placeResults[kind] = places

        var nextAvailable = availableKinds
        if places.isEmpty {
            nextAvailable.remove(kind)
        } else {
            nextAvailable.insert(kind)
        }
        availableKinds = nextAvailable
    }

    func openInMaps(_ place: DunnoNearbyPlace) {
        place.mapItem.openInMaps(launchOptions: nil)
    }

    func openLocationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func requestCurrentLocation(force: Bool) {
        guard isEnabled, isAuthorized else { return }

        if !force,
           let location = currentLocation,
           abs(location.timestamp.timeIntervalSinceNow) < commonSearchLifetime {
            refreshCommonKindsIfNeeded(near: location, force: false)
            return
        }

        guard !isLocating else { return }
        isLocating = true
        lastError = nil
        manager.requestLocation()
    }

    private func handleLocation(_ location: CLLocation) {
        guard location.horizontalAccuracy >= 0 else { return }
        guard abs(location.timestamp.timeIntervalSinceNow) < 2 * 60 else { return }

        if let previous = currentLocation,
           location.distance(from: previous) >= commonSearchMovementThreshold {
            // Place rows are intentionally memory-only. If the user has moved far enough
            // that the old results are no longer useful, drop them before searching again.
            placeResults = [:]
            availableKinds = []
            lastCommonSearchDate = nil
            lastCommonSearchLocation = nil
        }

        currentLocation = location
        isLocating = false
        lastError = nil
        refreshCommonKindsIfNeeded(near: location, force: false)

        let deferredKinds = pendingKinds.subtracting(DunnoNearbyKind.commonKinds)
        pendingKinds.removeAll()
        guard !deferredKinds.isEmpty else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            for kind in deferredKinds {
                guard !Task.isCancelled else { return }
                await loadAndStore(kind: kind, near: location, force: false)
            }
        }
    }

    private func refreshCommonKindsIfNeeded(near location: CLLocation, force: Bool) {
        let recentEnough: Bool
        if let date = lastCommonSearchDate {
            recentEnough = Date().timeIntervalSince(date) < commonSearchLifetime
        } else {
            recentEnough = false
        }

        let closeEnough: Bool
        if let previous = lastCommonSearchLocation {
            closeEnough = location.distance(from: previous) < commonSearchMovementThreshold
        } else {
            closeEnough = false
        }

        if !force, recentEnough, closeEnough { return }

        commonSearchTask?.cancel()
        commonSearchTask = Task { @MainActor [weak self] in
            guard let self else { return }

            var nextAvailable = availableKinds
            let kinds = DunnoNearbyKind.commonKinds
            loadingKinds.formUnion(kinds)
            defer {
                loadingKinds.subtract(kinds)
                commonSearchTask = nil
            }

            for kind in kinds {
                guard !Task.isCancelled else { return }
                let places = await search(kind: kind, near: location)
                // Publish place rows as each search finishes so an open activity detail
                // does not wait for the entire common-kind scan. Recommendation availability
                // is still published once at the end to avoid repeated queue reranks.
                placeResults[kind] = places
                if places.isEmpty {
                    nextAvailable.remove(kind)
                } else {
                    nextAvailable.insert(kind)
                }
            }

            guard !Task.isCancelled else { return }
            availableKinds = nextAvailable
            lastCommonSearchLocation = location
            lastCommonSearchDate = Date()
        }
    }

    private func search(kind: DunnoNearbyKind, near location: CLLocation) async -> [DunnoNearbyPlace] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = kind.searchQuery
        request.region = MKCoordinateRegion(
            center: location.coordinate,
            latitudinalMeters: kind.searchRadius * 2,
            longitudinalMeters: kind.searchRadius * 2
        )
        if kind == .trail {
            if #available(iOS 18.0, *) {
                request.resultTypes = [.pointOfInterest, .physicalFeature]
            } else {
                request.resultTypes = .pointOfInterest
            }
        } else {
            request.resultTypes = .pointOfInterest
        }

        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems
                .compactMap { mapItem -> DunnoNearbyPlace? in
                    guard let name = mapItem.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !name.isEmpty else { return nil }

                    let itemLocation = Self.location(for: mapItem)
                    let distance = location.distance(from: itemLocation)
                    guard distance <= kind.searchRadius * 1.35 else { return nil }

                    return DunnoNearbyPlace(
                        id: Self.placeID(kind: kind, name: name, location: itemLocation),
                        name: name,
                        distance: distance,
                        kind: kind,
                        mapItem: mapItem
                    )
                }
                .sorted { $0.distance < $1.distance }
                .reduce(into: [DunnoNearbyPlace]()) { result, place in
                    let normalizedName = place.name.lowercased()
                    guard !result.contains(where: { $0.name.lowercased() == normalizedName }) else { return }
                    if result.count < 5 { result.append(place) }
                }
        } catch is CancellationError {
            return []
        } catch {
            return []
        }
    }

    private static func location(for mapItem: MKMapItem) -> CLLocation {
        if #available(iOS 26.0, *) {
            return mapItem.location
        } else if let location = mapItem.placemark.location {
            return location
        } else {
            let coordinate = mapItem.placemark.coordinate
            return CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
    }

    private static func placeID(kind: DunnoNearbyKind, name: String, location: CLLocation) -> String {
        let latitude = (location.coordinate.latitude * 10_000).rounded() / 10_000
        let longitude = (location.coordinate.longitude * 10_000).rounded() / 10_000
        return "\(kind.rawValue)|\(name.lowercased())|\(latitude)|\(longitude)"
    }

    private func clearSessionLocation() {
        commonSearchTask?.cancel()
        commonSearchTask = nil
        currentLocation = nil
        lastCommonSearchLocation = nil
        lastCommonSearchDate = nil
        availableKinds = []
        placeResults = [:]
        loadingKinds = []
        pendingKinds = []
        isLocating = false
        lastError = nil
    }

    // CLLocationManagerDelegate is not actor-isolated in the SDK. Core Location delivers
    // these callbacks on the run loop where the manager was created (the main run loop here),
    // so bridge explicitly into this @MainActor service for Swift 6 correctness.
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            authorizationStatus = manager.authorizationStatus
            lastError = nil

            guard isEnabled else { return }
            switch authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                requestCurrentLocation(force: true)
            case .denied:
                clearSessionLocation()
                isEnabled = true
                defaults.set(true, forKey: Self.enabledStorageKey)
                lastError = "Location access is off for Dunno."
            case .restricted:
                clearSessionLocation()
                isEnabled = true
                defaults.set(true, forKey: Self.enabledStorageKey)
                lastError = "Location access is restricted on this device."
            case .notDetermined:
                break
            @unknown default:
                lastError = "Location isn't available right now."
            }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        MainActor.assumeIsolated {
            guard let newest = locations.last else {
                isLocating = false
                return
            }
            handleLocation(newest)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        MainActor.assumeIsolated {
            isLocating = false
            let nsError = error as NSError
            if nsError.domain == kCLErrorDomain,
               nsError.code == CLError.locationUnknown.rawValue {
                lastError = "Couldn't get a fresh location yet. Try again in a moment."
            } else if authorizationStatus == .denied {
                lastError = "Location access is off for Dunno."
            } else {
                lastError = "Couldn't check what's nearby right now."
            }
        }
    }
}
