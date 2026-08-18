import SwiftUI

struct RoutesView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List(model.routes) { route in
            NavigationLink {
                List(route.nodes) { node in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(node.instruction).font(.headline)
                        Text("提醒半径 \(Int(node.reminderRadiusMeters)) 米")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle(route.name)
                .overlay {
                    if route.nodes.isEmpty {
                        ContentUnavailableView(
                            "尚未录制节点",
                            systemImage: "map",
                            description: Text("首次路线采集后会在这里显示节点。")
                        )
                    }
                }
            } label: {
                RouteCard(route: route)
            }
        }
        .listStyle(.plain)
        .navigationTitle("我的路线")
        .toolbar {
            Button("录制", systemImage: "record.circle") {}
        }
    }
}
