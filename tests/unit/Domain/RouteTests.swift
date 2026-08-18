import XCTest
@testable import DrivingTrainerDomain

final class RouteTests: XCTestCase {
    func testRouteSortsNodesByOrder() {
        let coordinate = Coordinate(latitude: 30.45, longitude: 114.45)
        let later = RouteNode(coordinate: coordinate, order: 2, type: .pullOver, instruction: "靠边停车")
        let earlier = RouteNode(coordinate: coordinate, order: 1, type: .start, instruction: "起步")
        let route = Route(name: "1号线", venue: "同心考场", nodes: [later, earlier])

        XCTAssertEqual(route.nodes.map(\.order), [1, 2])
    }

    func testNodeReminderRadiusHasSafeMinimum() {
        let node = RouteNode(
            coordinate: Coordinate(latitude: 30.45, longitude: 114.45),
            order: 1,
            type: .school,
            instruction: "松油、点刹、观察",
            reminderRadiusMeters: 5
        )

        XCTAssertEqual(node.reminderRadiusMeters, 20)
    }
}
