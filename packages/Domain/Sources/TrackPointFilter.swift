import Foundation

public struct TrackPointFilter: Sendable {
    public let maximumHorizontalAccuracy: Double
    public let minimumDistanceMeters: Double
    public let maximumSilenceInterval: TimeInterval
    public let maximumSpeedMetersPerSecond: Double

    public init(
        maximumHorizontalAccuracy: Double = 50,
        minimumDistanceMeters: Double = 3,
        maximumSilenceInterval: TimeInterval = 5,
        maximumSpeedMetersPerSecond: Double = 60
    ) {
        self.maximumHorizontalAccuracy = maximumHorizontalAccuracy
        self.minimumDistanceMeters = minimumDistanceMeters
        self.maximumSilenceInterval = maximumSilenceInterval
        self.maximumSpeedMetersPerSecond = maximumSpeedMetersPerSecond
    }

    public func shouldAccept(_ candidate: TrackPoint, after previous: TrackPoint?) -> Bool {
        guard candidate.horizontalAccuracy >= 0,
              candidate.horizontalAccuracy <= maximumHorizontalAccuracy else {
            return false
        }
        guard let previous else { return true }

        let elapsed = candidate.timestamp.timeIntervalSince(previous.timestamp)
        guard elapsed > 0 else { return false }

        let distance = GeoDistance.meters(from: previous.coordinate, to: candidate.coordinate)
        let calculatedSpeed = distance / elapsed
        guard calculatedSpeed <= maximumSpeedMetersPerSecond else { return false }

        return distance >= minimumDistanceMeters || elapsed >= maximumSilenceInterval
    }
}
