import Foundation

public struct ReminderEngine: Sendable {
    public private(set) var nextNodeIndex: Int
    public private(set) var lastReminderAt: Date?
    public let cooldown: TimeInterval
    public let maximumUsableAccuracy: Double

    public init(
        nextNodeIndex: Int = 0,
        cooldown: TimeInterval = 20,
        maximumUsableAccuracy: Double = 65
    ) {
        self.nextNodeIndex = max(0, nextNodeIndex)
        self.cooldown = cooldown
        self.maximumUsableAccuracy = maximumUsableAccuracy
    }

    public mutating func evaluate(
        location: TrackPoint,
        nodes: [RouteNode],
        now: Date? = nil
    ) -> ReminderEvent? {
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= maximumUsableAccuracy,
              nextNodeIndex < nodes.count else {
            return nil
        }

        let timestamp = now ?? location.timestamp
        if let lastReminderAt,
           timestamp.timeIntervalSince(lastReminderAt) < cooldown {
            return nil
        }

        let node = nodes[nextNodeIndex]
        let distance = GeoDistance.meters(from: location.coordinate, to: node.coordinate)
        guard distance <= node.reminderRadiusMeters else { return nil }

        lastReminderAt = timestamp
        return ReminderEvent(node: node, distanceMeters: distance)
    }

    public mutating func completeCurrentNode() {
        nextNodeIndex += 1
        lastReminderAt = nil
    }

    public mutating func skipCurrentNode() {
        completeCurrentNode()
    }

    public mutating func reset() {
        nextNodeIndex = 0
        lastReminderAt = nil
    }
}

public struct ReminderEvent: Equatable, Sendable {
    public let node: RouteNode
    public let distanceMeters: Double

    public init(node: RouteNode, distanceMeters: Double) {
        self.node = node
        self.distanceMeters = distanceMeters
    }
}
