import Foundation
import XCTest
@testable import DrivingTrainerDomain

final class PracticeControllerTests: XCTestCase {
    private let coordinate = Coordinate(latitude: 30.45, longitude: 114.45)

    func testFullPracticeLifecycle() throws {
        let node = RouteNode(coordinate: coordinate, order: 0, type: .school, instruction: "减速观察")
        let route = Route(name: "测试路线", venue: "测试场地", nodes: [node])
        let start = Date(timeIntervalSince1970: 1_000)
        var controller = PracticeController(route: route)

        try controller.start(at: start)
        let reminder = try controller.receive(
            TrackPoint(coordinate: coordinate, timestamp: start.addingTimeInterval(1), horizontalAccuracy: 8)
        )
        try controller.markCurrentNode(.difficult, note: "点刹偏晚", at: start.addingTimeInterval(2))
        let result = try controller.finish(at: start.addingTimeInterval(10))

        XCTAssertEqual(reminder?.node.id, node.id)
        XCTAssertEqual(result.track.count, 1)
        XCTAssertEqual(result.attempts.first?.outcome, .difficult)
        XCTAssertEqual(controller.state, .finished)
    }

    func testPausedSessionDoesNotRecordPoint() throws {
        let route = Route(name: "测试路线", venue: "测试场地")
        var controller = PracticeController(route: route)
        try controller.start()
        try controller.pause()

        _ = try controller.receive(TrackPoint(coordinate: coordinate, horizontalAccuracy: 8))

        XCTAssertTrue(controller.session?.track.isEmpty == true)
    }

    func testCannotStartTwice() throws {
        let route = Route(name: "测试路线", venue: "测试场地")
        var controller = PracticeController(route: route)
        try controller.start()

        XCTAssertThrowsError(try controller.start()) { error in
            XCTAssertEqual(error as? PracticeControllerError, .sessionAlreadyStarted)
        }
    }
}
