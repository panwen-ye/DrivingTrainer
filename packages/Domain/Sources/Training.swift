import Foundation

public struct TrackPoint: Codable, Equatable, Sendable {
    public let coordinate: Coordinate
    public let timestamp: Date
    public let horizontalAccuracy: Double
    public let speedMetersPerSecond: Double?

    public init(
        coordinate: Coordinate,
        timestamp: Date = Date(),
        horizontalAccuracy: Double,
        speedMetersPerSecond: Double? = nil
    ) {
        self.coordinate = coordinate
        self.timestamp = timestamp
        self.horizontalAccuracy = horizontalAccuracy
        self.speedMetersPerSecond = speedMetersPerSecond
    }
}

public struct PracticeSession: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let routeID: UUID
    public let routeVersion: Int
    public let startedAt: Date
    public var endedAt: Date?
    public var track: [TrackPoint]
    public var attempts: [NodeAttempt]

    public init(
        id: UUID = UUID(),
        routeID: UUID,
        routeVersion: Int,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        track: [TrackPoint] = [],
        attempts: [NodeAttempt] = []
    ) {
        self.id = id
        self.routeID = routeID
        self.routeVersion = routeVersion
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.track = track
        self.attempts = attempts
    }
}

public struct NodeAttempt: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let nodeID: UUID
    public let recordedAt: Date
    public var outcome: AttemptOutcome
    public var note: String?

    public init(
        id: UUID = UUID(),
        nodeID: UUID,
        recordedAt: Date = Date(),
        outcome: AttemptOutcome,
        note: String? = nil
    ) {
        self.id = id
        self.nodeID = nodeID
        self.recordedAt = recordedAt
        self.outcome = outcome
        self.note = note
    }
}

public enum AttemptOutcome: String, Codable, Sendable {
    case completed
    case difficult
    case skipped
}
