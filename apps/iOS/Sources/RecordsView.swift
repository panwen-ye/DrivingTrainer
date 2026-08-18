import DrivingTrainerDomain
import SwiftUI

struct RecordsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List(model.sessions) { session in
            VStack(alignment: .leading, spacing: 6) {
                Text(session.startedAt, style: .date).font(.headline)
                Text("轨迹点 \(session.track.count) · 易错 \(difficultCount(in: session))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
}
