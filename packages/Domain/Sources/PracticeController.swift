import Foundation

public enum PracticeState: Equatable, Sendable {
    case idle
    case active
    case paused
    case finished
}

public enum PracticeControllerError: Error, Equatable {
    case sessionAlreadyStarted
    case sessionNotStarted
    case sessionFinished
    case noCurrentNode
}

public struct PracticeController: Sendable {
    public let route: Route
    public private(set) var state: PracticeState = .idle
    public private(set) var session: PracticeSession?
    public private(set) var reminderEngine: ReminderEngine
    private let pointFilter: TrackPointFilter

    public init(
        route: Route,
        reminderEngine: ReminderEngine = ReminderEngine(),
        pointFilter: TrackPointFilter = TrackPointFilter()
    ) {
        self.route = route
        self.reminderEngine = reminderEngine
        self.pointFilter = pointFilter
    }

    public var currentNode: RouteNode? {
        guard reminderEngine.nextNodeIndex < route.nodes.count else { return nil }
        return route.nodes[reminderEngine.nextNodeIndex]
    }

    public mutating func start(at date: Date = Date()) throws {
        guard state == .idle else { throw PracticeControllerError.sessionAlreadyStarted }
        session = PracticeSession(
            routeID: route.id,
            routeVersion: route.version,
            startedAt: date
        )
        state = .active
    }

    public mutating func pause() throws {
        try requireRunningSession()
        state = .paused
    }

    public mutating func resume() throws {
        guard session != nil else { throw PracticeControllerError.sessionNotStarted }
        guard state != .finished else { throw PracticeControllerError.sessionFinished }
        state = .active
    }

    @discardableResult
    public mutating func receive(_ point: TrackPoint) throws -> ReminderEvent? {
        try requireRunningSession()
        guard state == .active else { return nil }

        let previous = session?.track.last
        guard pointFilter.shouldAccept(point, after: previous) else { return nil }
        session?.track.append(point)
        return reminderEngine.evaluate(location: point, nodes: route.nodes)
    }

    public mutating func markCurrentNode(
        _ outcome: AttemptOutcome,
        note: String? = nil,
        at date: Date = Date()
    ) throws {
        try requireRunningSession()
        guard let node = currentNode else { throw PracticeControllerError.noCurrentNode }

        session?.attempts.append(
            NodeAttempt(nodeID: node.id, recordedAt: date, outcome: outcome, note: note)
        )
        reminderEngine.completeCurrentNode()
    }

    @discardableResult
    public mutating func finish(at date: Date = Date()) throws -> PracticeSession {
        guard var completedSession = session else {
            throw PracticeControllerError.sessionNotStarted
        }
        guard state != .finished else { throw PracticeControllerError.sessionFinished }

        completedSession.endedAt = date
        session = completedSession
        state = .finished
        return completedSession
    }

    private func requireRunningSession() throws {
        guard session != nil else { throw PracticeControllerError.sessionNotStarted }
        guard state != .finished else { throw PracticeControllerError.sessionFinished }
    }
}
