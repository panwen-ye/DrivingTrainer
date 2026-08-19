import DrivingTrainerDomain
import DrivingTrainerPersistence
import Foundation
import XCTest

final class TrainingWorkflowIntegrationTests: XCTestCase {
    func testRecordedRouteCanBeReloadedAndPracticedEndToEnd() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try DrivingDataStore(directory: directory)

        let start = Date(timeIntervalSince1970: 1_800_000_000)
        let firstCoordinate = Coordinate(latitude: 30.5928, longitude: 114.3055)
        let secondCoordinate = Coordinate(latitude: 30.5932, longitude: 114.3060)
        let route = Route(
            name: "集成测试路线",
            venue: "武汉同心考场",
            createdAt: start,
            path: [
                TrackPoint(coordinate: firstCoordinate, timestamp: start, horizontalAccuracy: 5),
                TrackPoint(coordinate: secondCoordinate, timestamp: start.addingTimeInterval(10), horizontalAccuracy: 6)
            ],
            nodes: [
                RouteNode(
                    coordinate: firstCoordinate,
                    order: 0,
                    type: .start,
                    instruction: "观察后起步",
                    reminderRadiusMeters: 80
                ),
                RouteNode(
                    coordinate: secondCoordinate,
                    order: 1,
                    type: .turnRight,
                    instruction: "前方右转",
                    reminderRadiusMeters: 100
                )
            ]
        )
        try await store.upsertRoute(route)

        let reloadedRoutes = try await store.routes()
        let reloadedRoute = try XCTUnwrap(reloadedRoutes.first)
        XCTAssertEqual(reloadedRoute, route)

        var controller = PracticeController(route: reloadedRoute)
        try controller.start(at: start.addingTimeInterval(60))

        let firstReminder = try controller.receive(
            TrackPoint(
                coordinate: firstCoordinate,
                timestamp: start.addingTimeInterval(61),
                horizontalAccuracy: 5
            )
        )
        XCTAssertEqual(firstReminder?.node.instruction, "观察后起步")
        try controller.markCurrentNode(.completed, at: start.addingTimeInterval(62))

        let secondReminder = try controller.receive(
            TrackPoint(
                coordinate: secondCoordinate,
                timestamp: start.addingTimeInterval(90),
                horizontalAccuracy: 5
            )
        )
        XCTAssertEqual(secondReminder?.node.instruction, "前方右转")
        try controller.markCurrentNode(.difficult, note: "转向灯偏晚", at: start.addingTimeInterval(91))

        let completed = try controller.finish(at: start.addingTimeInterval(120))
        try await store.saveSession(completed)

        let sessions = try await store.sessions()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].routeID, route.id)
        XCTAssertEqual(sessions[0].track.count, 2)
        XCTAssertEqual(sessions[0].attempts.map(\.outcome), [.completed, .difficult])
        XCTAssertEqual(sessions[0].attempts.last?.note, "转向灯偏晚")
    }

    func testEditingRouteReplacesExistingVersionWithoutDuplication() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try DrivingDataStore(directory: directory)
        var route = Route(name: "1号线", venue: "武汉同心考场")

        try await store.upsertRoute(route)
        route.version += 1
        route.nodes = [
            RouteNode(
                coordinate: Coordinate(latitude: 30.5, longitude: 114.3),
                order: 0,
                type: .school,
                instruction: "学校区域减速"
            )
        ]
        try await store.upsertRoute(route)

        let routes = try await store.routes()
        XCTAssertEqual(routes.count, 1)
        XCTAssertEqual(routes[0].version, 2)
        XCTAssertEqual(routes[0].nodes.first?.type, .school)
    }

    func testMultipleSessionsRemainNewestFirstAfterReload() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let route = Route(name: "3号线", venue: "武汉同心考场")
        let store = try DrivingDataStore(directory: directory)
        let older = PracticeSession(
            routeID: route.id,
            routeVersion: route.version,
            startedAt: Date(timeIntervalSince1970: 100)
        )
        let newer = PracticeSession(
            routeID: route.id,
            routeVersion: route.version,
            startedAt: Date(timeIntervalSince1970: 200)
        )

        try await store.saveSession(newer)
        try await store.saveSession(older)

        let sessionIDs = try await store.sessions().map(\.id)
        XCTAssertEqual(sessionIDs, [newer.id, older.id])
    }

    func testPauseResumeAndSkippedNodePersistInSession() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try DrivingDataStore(directory: directory)
        let start = Date(timeIntervalSince1970: 1_900_000_000)
        let first = Coordinate(latitude: 30.50, longitude: 114.30)
        let second = Coordinate(latitude: 30.51, longitude: 114.31)
        let route = Route(
            name: "暂停与跳过测试",
            venue: "武汉同心考场",
            nodes: [
                RouteNode(coordinate: first, order: 0, type: .start, instruction: "准备起步"),
                RouteNode(coordinate: second, order: 1, type: .uTurn, instruction: "前方掉头")
            ]
        )

        var controller = PracticeController(route: route)
        try controller.start(at: start)
        try controller.pause()
        _ = try controller.receive(
            TrackPoint(coordinate: first, timestamp: start.addingTimeInterval(1), horizontalAccuracy: 5)
        )
        XCTAssertTrue(controller.session?.track.isEmpty == true)

        try controller.resume()
        _ = try controller.receive(
            TrackPoint(coordinate: first, timestamp: start.addingTimeInterval(2), horizontalAccuracy: 5)
        )
        try controller.markCurrentNode(.skipped, note: "本轮不练起步", at: start.addingTimeInterval(3))
        try controller.markCurrentNode(.completed, at: start.addingTimeInterval(4))

        let session = try controller.finish(at: start.addingTimeInterval(20))
        try await store.saveSession(session)
        let sessions = try await store.sessions()
        let reloaded = try XCTUnwrap(sessions.first)

        XCTAssertEqual(reloaded.track.count, 1)
        XCTAssertEqual(reloaded.attempts.map(\.outcome), [.skipped, .completed])
        XCTAssertEqual(reloaded.attempts.first?.note, "本轮不练起步")
        XCTAssertEqual(reloaded.endedAt, start.addingTimeInterval(20))
    }

    func testImportedPathUpdatePreservesExamNodes() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try DrivingDataStore(directory: directory)
        let node = RouteNode(
            coordinate: Coordinate(latitude: 30.60, longitude: 114.30),
            order: 0,
            type: .trafficLight,
            instruction: "路口观察信号灯"
        )
        let announcement = ExamAnnouncement(
            coordinate: node.coordinate,
            order: 0,
            project: .intersection
        )
        var route = Route(
            name: "1号线",
            venue: "武汉同心考场",
            nodes: [node],
            announcements: [announcement]
        )
        try await store.upsertRoute(route)

        route.path = [
            TrackPoint(
                coordinate: Coordinate(latitude: 30.60, longitude: 114.30),
                horizontalAccuracy: 0
            ),
            TrackPoint(
                coordinate: Coordinate(latitude: 30.61, longitude: 114.31),
                horizontalAccuracy: 0
            )
        ]
        route.version += 1
        try await store.upsertRoute(route)

        let routes = try await store.routes()
        let reloaded = try XCTUnwrap(routes.first)
        XCTAssertEqual(reloaded.path.count, 2)
        XCTAssertEqual(reloaded.nodes, [node])
        XCTAssertEqual(reloaded.announcements, [announcement])
        XCTAssertEqual(reloaded.version, 2)
    }

    func testExamAnnouncementsPersistAndTriggerIndependentlyFromTrainingNodes() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try DrivingDataStore(directory: directory)
        let coordinate = Coordinate(latitude: 30.62, longitude: 114.32)
        let trainingNode = RouteNode(
            coordinate: coordinate,
            order: 0,
            type: .straightDriving,
            instruction: "保持方向稳定，不要看挡位"
        )
        let announcement = ExamAnnouncement(
            coordinate: coordinate,
            order: 0,
            project: .straightDriving,
            triggerRadiusMeters: 60
        )
        let route = Route(
            name: "播报隔离测试",
            venue: "武汉同心考场",
            nodes: [trainingNode],
            announcements: [announcement]
        )
        try await store.upsertRoute(route)

        let routes = try await store.routes()
        let reloaded = try XCTUnwrap(routes.first)
        XCTAssertEqual(reloaded.nodes.first?.instruction, "保持方向稳定，不要看挡位")
        XCTAssertEqual(reloaded.announcements.first?.project.announcementText, "开始直线行驶")

        var engine = ExamAnnouncementEngine(minimumInterval: 0)
        let event = engine.evaluate(
            location: TrackPoint(coordinate: coordinate, horizontalAccuracy: 5),
            announcements: reloaded.announcements
        )
        XCTAssertEqual(event?.announcement.project.announcementText, "开始直线行驶")
        XCTAssertNotEqual(event?.announcement.project.announcementText, reloaded.nodes.first?.instruction)
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("DrivingTrainerIntegration-\(UUID().uuidString)", isDirectory: true)
    }
}
