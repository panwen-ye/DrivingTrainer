import Foundation

public struct Route: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var venue: String
    public var version: Int
    public let createdAt: Date
    public var path: [TrackPoint]
    public var nodes: [RouteNode]
    public var announcements: [ExamAnnouncement]

    public init(
        id: UUID = UUID(),
        name: String,
        venue: String,
        version: Int = 1,
        createdAt: Date = Date(),
        path: [TrackPoint] = [],
        nodes: [RouteNode] = [],
        announcements: [ExamAnnouncement] = []
    ) {
        self.id = id
        self.name = name
        self.venue = venue
        self.version = version
        self.createdAt = createdAt
        self.path = path
        self.nodes = nodes.sorted { $0.order < $1.order }
        self.announcements = announcements.sorted { $0.order < $1.order }
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, venue, version, createdAt, path, nodes, announcements
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        venue = try container.decode(String.self, forKey: .venue)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        path = try container.decodeIfPresent([TrackPoint].self, forKey: .path) ?? []
        nodes = try container.decodeIfPresent([RouteNode].self, forKey: .nodes)?.sorted { $0.order < $1.order } ?? []
        announcements = try container.decodeIfPresent([ExamAnnouncement].self, forKey: .announcements)?
            .sorted { $0.order < $1.order } ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(venue, forKey: .venue)
        try container.encode(version, forKey: .version)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(path, forKey: .path)
        try container.encode(nodes, forKey: .nodes)
        try container.encode(announcements, forKey: .announcements)
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
