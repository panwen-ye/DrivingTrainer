import Foundation

public struct Route: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var venue: String
    public var version: Int
    public let createdAt: Date
    public var path: [TrackPoint]
    public var nodes: [RouteNode]

    public init(
        id: UUID = UUID(),
        name: String,
        venue: String,
        version: Int = 1,
        createdAt: Date = Date(),
        path: [TrackPoint] = [],
        nodes: [RouteNode] = []
    ) {
        self.id = id
        self.name = name
        self.venue = venue
        self.version = version
        self.createdAt = createdAt
        self.path = path
        self.nodes = nodes.sorted { $0.order < $1.order }
    }
}

public struct RouteNode: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var coordinate: Coordinate
    public var order: Int
    public var type: NodeType
    public var instruction: String
    public var reminderRadiusMeters: Double

    public init(
        id: UUID = UUID(),
        coordinate: Coordinate,
        order: Int,
        type: NodeType,
        instruction: String,
        reminderRadiusMeters: Double = 120
    ) {
        self.id = id
        self.coordinate = coordinate
        self.order = order
        self.type = type
        self.instruction = instruction
        self.reminderRadiusMeters = max(20, reminderRadiusMeters)
    }
}

public enum NodeType: String, Codable, CaseIterable, Sendable {
    case start
    case trafficLight
    case turnLeft
    case turnRight
    case laneChange
    case overtake
    case school
    case busStop
    case meeting
    case straightDriving
    case speedControl
    case uTurn
    case pullOver
    case custom
}
