import DrivingTrainerDomain
import Foundation

public actor DrivingDataStore {
    private let routesStore: JSONStore<[Route]>
    private let sessionsStore: JSONStore<[PracticeSession]>

    public init(directory: URL) throws {
        routesStore = try JSONStore(directory: directory, filename: "routes.json")
        sessionsStore = try JSONStore(directory: directory, filename: "practice-sessions.json")
    }

    public func routes() async throws -> [Route] {
        try await routesStore.load(default: [])
    }

    public func saveRoutes(_ routes: [Route]) async throws {
        try await routesStore.save(routes)
    }

    public func upsertRoute(_ route: Route) async throws {
        var current = try await routes()
        if let index = current.firstIndex(where: { $0.id == route.id }) {
            current[index] = route
        } else {
            current.append(route)
        }
        try await saveRoutes(current)
    }

    public func sessions() async throws -> [PracticeSession] {
        try await sessionsStore.load(default: [])
    }

    public func saveSession(_ session: PracticeSession) async throws {
        var current = try await sessions()
        if let index = current.firstIndex(where: { $0.id == session.id }) {
            current[index] = session
        } else {
            current.append(session)
        }
        current.sort { $0.startedAt > $1.startedAt }
        try await sessionsStore.save(current)
    }
}
