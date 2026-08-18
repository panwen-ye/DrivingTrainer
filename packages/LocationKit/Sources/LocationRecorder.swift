@preconcurrency import CoreLocation
import Combine
import DrivingTrainerDomain
import Foundation

public enum LocationRecorderState: Equatable, Sendable {
    case idle
    case recording
    case paused
}

@MainActor
public final class LocationRecorder: NSObject, ObservableObject {
    @Published public private(set) var authorizationStatus: CLAuthorizationStatus
    @Published public private(set) var state: LocationRecorderState = .idle
    @Published public private(set) var latestPoint: TrackPoint?
    @Published public private(set) var track: [TrackPoint] = []
    @Published public private(set) var lastError: Error?

    private let manager: CLLocationManager
    private let pointFilter: TrackPointFilter

    public init(
        manager: CLLocationManager = CLLocationManager(),
        pointFilter: TrackPointFilter = TrackPointFilter()
    ) {
        self.manager = manager
        self.pointFilter = pointFilter
        self.authorizationStatus = manager.authorizationStatus
        super.init()

        manager.delegate = self
        manager.activityType = .automotiveNavigation
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 2
        manager.pausesLocationUpdatesAutomatically = true
    }

    public func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    public func start(clearExistingTrack: Bool = true) {
        if clearExistingTrack {
            track.removeAll(keepingCapacity: true)
            latestPoint = nil
        }
        lastError = nil
        state = .recording
        manager.startUpdatingLocation()
    }

    public func pause() {
        guard state == .recording else { return }
        state = .paused
        manager.stopUpdatingLocation()
    }

    public func resume() {
        guard state == .paused else { return }
        state = .recording
        manager.startUpdatingLocation()
    }

    @discardableResult
    public func stop() -> [TrackPoint] {
        manager.stopUpdatingLocation()
        state = .idle
        return track
    }
}

extension LocationRecorder: @preconcurrency CLLocationManagerDelegate {
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard state == .recording else { return }

        for location in locations {
            let point = TrackPoint(
                coordinate: Coordinate(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                ),
                timestamp: location.timestamp,
                horizontalAccuracy: location.horizontalAccuracy,
                speedMetersPerSecond: location.speed >= 0 ? location.speed : nil
            )
            guard pointFilter.shouldAccept(point, after: track.last) else { continue }
            track.append(point)
            latestPoint = point
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastError = error
    }
}
