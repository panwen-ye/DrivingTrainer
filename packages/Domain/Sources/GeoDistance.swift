import Foundation

public enum GeoDistance {
    private static let earthRadiusMeters = 6_371_000.0

    public static func meters(from start: Coordinate, to end: Coordinate) -> Double {
        let latitude1 = start.latitude * .pi / 180
        let latitude2 = end.latitude * .pi / 180
        let latitudeDelta = (end.latitude - start.latitude) * .pi / 180
        let longitudeDelta = (end.longitude - start.longitude) * .pi / 180

        let a = sin(latitudeDelta / 2) * sin(latitudeDelta / 2)
            + cos(latitude1) * cos(latitude2)
            * sin(longitudeDelta / 2) * sin(longitudeDelta / 2)
        let angle = 2 * atan2(sqrt(a), sqrt(1 - a))
        return earthRadiusMeters * angle
    }
}
