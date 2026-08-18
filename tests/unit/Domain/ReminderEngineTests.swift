import Foundation
import XCTest
@testable import DrivingTrainerDomain

final class ReminderEngineTests: XCTestCase {
    private let nodeCoordinate = Coordinate(latitude: 30.45, longitude: 114.45)

    func testTriggersInsideReminderRadius() {
        let node = RouteNode(
            coordinate: nodeCoordinate,
            order: 0,
            type: .school,
            instruction: "松油、点刹、观察",
            reminderRadiusMeters: 120
        )
        let point = TrackPoint(
            coordinate: Coordinate(latitude: 30.4505, longitude: 114.45),
            timestamp: Date(timeIntervalSince1970: 1_000),
            horizontalAccuracy: 8
        )
        var engine = ReminderEngine()

        let event = engine.evaluate(location: point, nodes: [node])

        XCTAssertEqual(event?.node.id, node.id)
    }

    func testCooldownPreventsRepeatedReminder() {
        let node = RouteNode(
            coordinate: nodeCoordinate,
            order: 0,
            type: .busStop,
            instruction: "减速观察"
        )
        let start = Date(timeIntervalSince1970: 1_000)
        let point = TrackPoint(coordinate: nodeCoordinate, timestamp: start, horizontalAccuracy: 8)
        var engine = ReminderEngine(cooldown: 20)

        XCTAssertNotNil(engine.evaluate(location: point, nodes: [node]))
        XCTAssertNil(engine.evaluate(location: point, nodes: [node], now: start.addingTimeInterval(10)))
    }

    func testCompletingNodeAdvancesInOrder() {
        let first = RouteNode(coordinate: nodeCoordinate, order: 0, type: .start, instruction: "起步")
        let second = RouteNode(coordinate: nodeCoordinate, order: 1, type: .pullOver, instruction: "靠边停车")
        let point = TrackPoint(coordinate: nodeCoordinate, horizontalAccuracy: 8)
        var engine = ReminderEngine()

        XCTAssertEqual(engine.evaluate(location: point, nodes: [first, second])?.node.id, first.id)
        engine.completeCurrentNode()
        XCTAssertEqual(engine.evaluate(location: point, nodes: [first, second])?.node.id, second.id)
    }
}
