# 数据模型草案

| 实体 | 关键字段 | 说明 |
|---|---|---|
| Route | id, name, venue, version, createdAt | 一条考试或训练路线 |
| Track | id, routeId, startedAt, endedAt, distance | 一次录制得到的轨迹 |
| TrackPoint | latitude, longitude, altitude, accuracy, timestamp | 原始/过滤后的定位点 |
| RouteNode | id, routeId, coordinate, order, type, reminderRadius | 路线节点 |
| Instruction | title, phrase, priority | 节点操作要求与口诀 |
| PracticeSession | routeId, startedAt, endedAt, status | 一次训练会话 |
| NodeAttempt | sessionId, nodeId, outcome, note | 节点完成和复盘结果 |
| AppSettings | speech, haptics, units, privacy | 本地设置 |

设计约束：实体使用稳定 UUID；轨迹点与业务节点分开；路线可版本化；训练记录引用当时的路线版本。MVP 全部模型遵循 `Codable`，分别保存路线、设置和训练记录，写入采用临时文件替换以降低损坏风险。
