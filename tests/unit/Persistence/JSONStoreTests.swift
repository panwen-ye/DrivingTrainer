import DrivingTrainerDomain
import DrivingTrainerPersistence
import Foundation
import XCTest

final class JSONStoreTests: XCTestCase {
    func testStoreReturnsDefaultWhenFileDoesNotExist() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = try JSONStore<[Route]>(directory: directory, filename: "routes.json")
        let routes = try await store.load(default: [])

        XCTAssertTrue(routes.isEmpty)
    }

    func testStoreRoundTripsRoutes() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let expected = [Route(name: "1号线", venue: "同心考场")]
        let store = try JSONStore<[Route]>(directory: directory, filename: "routes.json")
        try await store.save(expected)
        let actual = try await store.load(default: [])

        XCTAssertEqual(actual, expected)
    }

    func testStoreRejectsNestedFilename() {
        let directory = FileManager.default.temporaryDirectory

        XCTAssertThrowsError(
            try JSONStore<[Route]>(directory: directory, filename: "../routes.json")
        ) { error in
            XCTAssertEqual(error as? JSONStoreError, .invalidFilename)
        }
    }
}
