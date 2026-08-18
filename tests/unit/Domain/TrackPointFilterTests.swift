import Foundation
import XCTest
@testable import DrivingTrainerDomain

final class TrackPointFilterTests: XCTestCase {
    private let origin = Coordinate(latitude: 30.45, longitude: 114.45)

    func testRejectsInaccuratePoint() {
        let point = TrackPoint(coordinate: origin, horizontalAccuracy: 80)
        XCTAssertFalse(TrackPointFilter().shouldAccept(point, after: nil))
    }

    func testAcceptsFirstAccuratePoint() {
        let point = TrackPoint(coordinate: origin, horizontalAccuracy: 8)
        XCTAssertTrue(TrackPointFilter().shouldAccept(point, after: nil))
    }

    func testRejectsImplausibleJump() {
        let startTime = Date(timeIntervalSince1970: 1_000)
        let previous = TrackPoint(coordinate: origin, timestamp: startTime, horizontalAccuracy: 8)
        let candidate = TrackPoint(
            coordinate: Coordinate(latitude: 30.46, longitude: 114.45),
            timestamp: startTime.addingTimeInterval(1),
            horizontalAccuracy: 8
        )

        XCTAssertFalse(TrackPointFilter().shouldAccept(candidate, after: previous))
    }
}
