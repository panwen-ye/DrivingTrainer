import Combine
import DrivingTrainerDomain
import DrivingTrainerPersistence
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var routes: [Route] = []
    @Published private(set) var sessions: [PracticeSession] = []
    @Published var errorMessage: String?

    private var store: DrivingDataStore?

    init() {
        do {
            let supportDirectory = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            store = try DrivingDataStore(directory: supportDirectory)
        } catch {
            errorMessage = "无法打开本地数据：\(error.localizedDescription)"
        }
    }

    func load() async {
        guard let store else { return }
        do {
            var loadedRoutes = try await store.routes()
            if loadedRoutes.isEmpty {
                loadedRoutes = Self.initialRoutes
                try await store.saveRoutes(loadedRoutes)
            }
            routes = loadedRoutes
            sessions = try await store.sessions()
        } catch {
            errorMessage = "读取训练数据失败：\(error.localizedDescription)"
        }
    }

    func save(_ session: PracticeSession) async {
        guard let store else { return }
        do {
            try await store.saveSession(session)
            sessions = try await store.sessions()
        } catch {
            errorMessage = "保存训练记录失败：\(error.localizedDescription)"
        }
    }

    func saveRoute(_ route: Route) async {
        guard let store else { return }
        do {
            try await store.upsertRoute(route)
            routes = try await store.routes()
        } catch {
            errorMessage = "保存路线失败：\(error.localizedDescription)"
        }
    }

    private static let initialRoutes: [Route] = [
        Route(name: "1号线", venue: "武汉同心考场"),
        Route(name: "3号线", venue: "武汉同心考场"),
        Route(name: "4号线", venue: "武汉同心考场")
    ]
}
