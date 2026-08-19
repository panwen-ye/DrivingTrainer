import Foundation

public struct ExamAnnouncement: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var coordinate: Coordinate
    public var order: Int
    public var project: ExamProjectType
    public var triggerRadiusMeters: Double

    public init(
        id: UUID = UUID(),
        coordinate: Coordinate,
        order: Int,
        project: ExamProjectType,
        triggerRadiusMeters: Double = 80
    ) {
        self.id = id
        self.coordinate = coordinate
        self.order = order
        self.project = project
        self.triggerRadiusMeters = max(20, triggerRadiusMeters)
    }
}

public enum ExamProjectType: String, Codable, CaseIterable, Sendable {
    case start
    case straightDriving
    case laneChange
    case turnLeft
    case turnRight
    case intersection
    case crosswalk
    case schoolZone
    case busStop
    case meeting
    case overtake
    case uTurn
    case pullOver

    public var displayName: String {
        switch self {
        case .start: "起步"
        case .straightDriving: "直线行驶"
        case .laneChange: "变更车道"
        case .turnLeft: "路口左转"
        case .turnRight: "路口右转"
        case .intersection: "通过路口"
        case .crosswalk: "通过人行横道"
        case .schoolZone: "通过学校区域"
        case .busStop: "通过公共汽车站"
        case .meeting: "会车"
        case .overtake: "超车"
        case .uTurn: "掉头"
        case .pullOver: "靠边停车"
        }
    }

    public var announcementText: String {
        switch self {
        case .start: "开始起步"
        case .straightDriving: "开始直线行驶"
        case .laneChange: "开始变更车道"
        case .turnLeft: "前方路口左转"
        case .turnRight: "前方路口右转"
        case .intersection: "前方通过路口"
        case .crosswalk: "前方通过人行横道"
        case .schoolZone: "前方通过学校区域"
        case .busStop: "前方通过公共汽车站"
        case .meeting: "开始会车"
        case .overtake: "开始超车"
        case .uTurn: "前方请选择合适地点掉头"
        case .pullOver: "请靠边停车"
        }
    }
}

