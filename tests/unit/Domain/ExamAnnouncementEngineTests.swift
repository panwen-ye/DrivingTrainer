import Foundation
import XCTest
@testable import DrivingTrainerDomain

final class ExamAnnouncementEngineTests: XCTestCase {
    private let coordinate = Coordinate(latitude: 30.45, longitude: 114.45)

    func testAnnouncementTriggersAndAutomaticallyAdvances() {
        let first = ExamAnnouncement(coordinate: coordinate, order: 0, project: .straightDriving)
        let second = ExamAnnouncement(coordinate: coordinate, order: 1, project: .laneChange)
        let start = Date(timeIntervalSince1970: 1_000)
        var engine = ExamAnnouncementEngine(minimumInterval: 0)

        let firstEvent = engine.evaluate(
            location: TrackPoint(coordinate: coordinate, timestamp: start, horizontalAccuracy: 5),
            announcements: [first, second]
        )
        let secondEvent = engine.evaluate(
            location: TrackPoint(coordinate: coordinate, timestamp: start.addingTimeInterval(1), horizontalAccuracy: 5),
            announcements: [first, second]
        )

        XCTAssertEqual(firstEvent?.announcement.project, .straightDriving)
        XCTAssertEqual(secondEvent?.announcement.project, .laneChange)
        XCTAssertEqual(engine.nextAnnouncementIndex, 2)
    }

    func testAnnouncementDoesNotTriggerOutsideRadius() {
        let announcement = ExamAnnouncement(
            coordinate: coordinate,
            order: 0,
            project: .pullOver,
            triggerRadiusMeters: 30
        )
        let distant = TrackPoint(
            coordinate: Coordinate(latitude: 30.46, longitude: 114.45),
            horizontalAccuracy: 5
        )
        var engine = ExamAnnouncementEngine()

        XCTAssertNil(engine.evaluate(location: distant, announcements: [announcement]))
        XCTAssertEqual(engine.nextAnnouncementIndex, 0)
    }

    func testPoorAccuracyAndMinimumIntervalPreventWrongAnnouncement() {
        let first = ExamAnnouncement(coordinate: coordinate, order: 0, project: .start)
        let second = ExamAnnouncement(coordinate: coordinate, order: 1, project: .overtake)
        let start = Date(timeIntervalSince1970: 2_000)
        var engine = ExamAnnouncementEngine(minimumInterval: 5, maximumUsableAccuracy: 30)

        XCTAssertNil(
            engine.evaluate(
                location: TrackPoint(coordinate: coordinate, timestamp: start, horizontalAccuracy: 80),
                announcements: [first, second]
            )
        )
        XCTAssertNotNil(
            engine.evaluate(
                location: TrackPoint(coordinate: coordinate, timestamp: start, horizontalAccuracy: 5),
                announcements: [first, second]
            )
        )
        XCTAssertNil(
            engine.evaluate(
                location: TrackPoint(
                    coordinate: coordinate,
                    timestamp: start.addingTimeInterval(2),
                    horizontalAccuracy: 5
                ),
                announcements: [first, second]
            )
        )
        XCTAssertEqual(engine.nextAnnouncementIndex, 1)
    }
}

