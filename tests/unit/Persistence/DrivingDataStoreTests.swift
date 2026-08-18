import DrivingTrainerDomain
import DrivingTrainerPersistence
import Foundation
import XCTest

final class DrivingDataStoreTests: XCTestCase {
    func testUpsertRouteReplacesSameIdentifier() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try DrivingDataStore(directory: directory)
        let id = UUID()

        try await store.upsertRoute(Route(id: id, name: "旧名称", venue: "同心考场"))
        try await store.upsertRoute(Route(id: id, name: "新名称", venue: "同心考场", version: 2))
        let routes = try await store.routes()

        XCTAssertEqual(routes.count, 1)
        XCTAssertEqual(routes.first?.name, "新名称")
        XCTAssertEqual(routes.first?.version, 2)
    }

    func testSessionsAreNewestFirst() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try DrivingDataStore(directory: directory)
        let routeID = UUID()
        let older = PracticeSession(routeID: routeID, routeVersion: 1, startedAt: Date(timeIntervalSince1970: 100))
        let newer = PracticeSession(routeID: routeID, routeVersion: 1, startedAt: Date(timeIntervalSince1970: 200))

        try await store.saveSession(older)
        try await store.saveSession(newer)
        let sessions = try await store.sessions()

        XCTAssertEqual(sessions.map(\.id), [newer.id, older.id])
    }
}
