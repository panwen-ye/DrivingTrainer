import XCTest
@testable import DrivingTrainerDomain

final class GeoDistanceTests: XCTestCase {
    func testSameCoordinateHasZeroDistance() {
        let coordinate = Coordinate(latitude: 30.45, longitude: 114.45)
        XCTAssertEqual(GeoDistance.meters(from: coordinate, to: coordinate), 0, accuracy: 0.001)
    }

    func testNearbyCoordinateDistanceIsReasonable() {
        let start = Coordinate(latitude: 30.45, longitude: 114.45)
        let end = Coordinate(latitude: 30.451, longitude: 114.45)
        XCTAssertEqual(GeoDistance.meters(from: start, to: end), 111.2, accuracy: 1)
    }
}
