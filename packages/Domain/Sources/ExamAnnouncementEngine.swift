import Foundation

public struct ExamAnnouncementEngine: Sendable {
    public private(set) var nextAnnouncementIndex: Int
    public private(set) var lastAnnouncementAt: Date?
    public let minimumInterval: TimeInterval
    public let maximumUsableAccuracy: Double

    public init(
        nextAnnouncementIndex: Int = 0,
        minimumInterval: TimeInterval = 5,
        maximumUsableAccuracy: Double = 65
    ) {
        self.nextAnnouncementIndex = max(0, nextAnnouncementIndex)
        self.minimumInterval = minimumInterval
        self.maximumUsableAccuracy = maximumUsableAccuracy
    }

    public mutating func evaluate(
        location: TrackPoint,
        announcements: [ExamAnnouncement],
        now: Date? = nil
    ) -> ExamAnnouncementEvent? {
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= maximumUsableAccuracy,
              nextAnnouncementIndex < announcements.count else {
            return nil
        }

        let timestamp = now ?? location.timestamp
        if let lastAnnouncementAt,
           timestamp.timeIntervalSince(lastAnnouncementAt) < minimumInterval {
            return nil
        }

        let announcement = announcements[nextAnnouncementIndex]
        let distance = GeoDistance.meters(from: location.coordinate, to: announcement.coordinate)
        guard distance <= announcement.triggerRadiusMeters else { return nil }

        nextAnnouncementIndex += 1
        lastAnnouncementAt = timestamp
        return ExamAnnouncementEvent(announcement: announcement, distanceMeters: distance)
    }

    public mutating func reset() {
        nextAnnouncementIndex = 0
        lastAnnouncementAt = nil
    }
}

public struct ExamAnnouncementEvent: Equatable, Sendable {
    public let announcement: ExamAnnouncement
    public let distanceMeters: Double

    public init(announcement: ExamAnnouncement, distanceMeters: Double) {
        self.announcement = announcement
        self.distanceMeters = distanceMeters
    }
}

