import DrivingTrainerDomain
import SwiftUI

struct RecordsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List(model.sessions) { session in
            NavigationLink {
                SessionDetailView(
                    session: session,
                    route: model.routes.first(where: { $0.id == session.routeID })
                )
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(routeName(for: session)).font(.headline)
                    Text(session.startedAt, format: .dateTime.year().month().day().hour().minute())
                        .font(.subheadline)
                    Text("轨迹点 \(session.track.count) · 易错 \(difficultCount(in: session))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .overlay {
            if model.sessions.isEmpty {
                ContentUnavailableView(
                    "还没有训练记录",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("完成一次路线训练后会自动生成复盘记录。")
                )
            }
        }
        .navigationTitle("训练记录")
    }

    private func difficultCount(in session: PracticeSession) -> Int {
        session.attempts.filter { $0.outcome == .difficult }.count
    }

    private func routeName(for session: PracticeSession) -> String {
        model.routes.first(where: { $0.id == session.routeID })?.name ?? "历史路线"
    }
}

private struct SessionDetailView: View {
    let session: PracticeSession
    let route: Route?

    var body: some View {
        List {
            Section("训练摘要") {
                LabeledContent("路线", value: route?.name ?? "历史路线")
                LabeledContent("开始", value: session.startedAt.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("时长", value: durationText)
                LabeledContent("轨迹点", value: "\(session.track.count)")
                LabeledContent("完成", value: "\(count(.completed))")
                LabeledContent("易错", value: "\(count(.difficult))")
                LabeledContent("跳过", value: "\(count(.skipped))")
            }

            Section("节点结果") {
                if session.attempts.isEmpty {
                    Text("本次训练没有节点结果。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(session.attempts) { attempt in
                        HStack(spacing: 12) {
                            Image(systemName: icon(for: attempt.outcome))
                                .foregroundStyle(color(for: attempt.outcome))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(node(for: attempt)?.instruction ?? "已删除的节点")
                                    .font(.headline)
                                Text(label(for: attempt.outcome))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("训练复盘")
    }

    private var durationText: String {
        guard let endedAt = session.endedAt else { return "未正常结束" }
        let seconds = max(0, Int(endedAt.timeIntervalSince(session.startedAt)))
        return String(format: "%d 分 %02d 秒", seconds / 60, seconds % 60)
    }

    private func count(_ outcome: AttemptOutcome) -> Int {
        session.attempts.filter { $0.outcome == outcome }.count
    }

    private func node(for attempt: NodeAttempt) -> RouteNode? {
        route?.nodes.first(where: { $0.id == attempt.nodeID })
    }

    private func label(for outcome: AttemptOutcome) -> String {
        switch outcome {
        case .completed: "已完成"
        case .difficult: "有困难"
        case .skipped: "已跳过"
        }
    }

    private func icon(for outcome: AttemptOutcome) -> String {
        switch outcome {
        case .completed: "checkmark.circle.fill"
        case .difficult: "exclamationmark.triangle.fill"
        case .skipped: "forward.end.circle.fill"
        }
    }

    private func color(for outcome: AttemptOutcome) -> Color {
        switch outcome {
        case .completed: .green
        case .difficult: .orange
        case .skipped: .secondary
        }
    }
}
