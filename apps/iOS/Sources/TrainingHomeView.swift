import DrivingTrainerDomain
import SwiftUI

struct TrainingHomeView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                safetyCard

                Text("选择训练路线")
                    .font(.title2.bold())

                ForEach(model.routes) { route in
                    NavigationLink {
                        TrainingPreviewView(route: route)
                    } label: {
                        RouteCard(route: route)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle("驾考训练")
    }

    private var safetyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("驾驶安全优先", systemImage: "shield.checkered")
                .font(.headline)
            Text("行驶中只使用语音和震动提醒；路线编辑请在停车后完成。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct TrainingPreviewView: View {
    let route: Route

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "location.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
            Text(route.name).font(.largeTitle.bold())
            Text(route.nodes.isEmpty ? "路线节点等待首次实地录制" : "包含 \(route.nodes.count) 个训练节点")
                .foregroundStyle(.secondary)
            Button("开始训练") {}
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(route.nodes.isEmpty)
        }
        .padding()
        .navigationTitle("训练准备")
    }
}

struct RouteCard: View {
    let route: Route

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "road.lanes")
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(route.name).font(.headline)
                Text("\(route.venue) · \(route.nodes.count) 个节点")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(.quaternary) }
    }
}
