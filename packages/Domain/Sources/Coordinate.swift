import Foundation

public struct Coordinate: Codable, Hashable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        precondition((-90...90).contains(latitude), "Latitude must be between -90 and 90")
        precondition((-180...180).contains(longitude), "Longitude must be between -180 and 180")
        self.latitude = latitude
        self.longitude = longitude
    }
}
