import DrivingTrainerDomain
import SwiftUI

struct RoutesView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List(model.routes) { route in
            NavigationLink {
                RouteDetailView(route: route)
            } label: {
                RouteCard(route: route)
            }
        }
        .listStyle(.plain)
        .navigationTitle("我的路线")
        .toolbar {
            NavigationLink {
                RecordingView()
            } label: {
                Label("录制", systemImage: "record.circle")
            }
        }
    }
}

private struct RouteDetailView: View {
    @EnvironmentObject private var model: AppModel
    @State private var route: Route
    @State private var editingNode: RouteNode?

    init(route: Route) { _route = State(initialValue: route) }

    var body: some View {
        List {
            ForEach(route.nodes) { node in
                Button {
                    editingNode = node
                } label: {
                    HStack {
                        Text("\(node.order + 1)")
                            .font(.caption.bold())
                            .frame(width: 28, height: 28)
                            .background(.blue.opacity(0.12), in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text(node.instruction).font(.headline).foregroundStyle(.primary)
                            Text("\(node.type.title) · 提前 \(Int(node.reminderRadiusMeters)) 米提醒")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onDelete(perform: deleteNodes)
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
        .sheet(item: $editingNode) { node in
            NodeEditorView(node: node) { updated in
                guard let index = route.nodes.firstIndex(where: { $0.id == updated.id }) else { return }
                route.nodes[index] = updated
                persist()
            }
        }
    }

    private func deleteNodes(at offsets: IndexSet) {
        route.nodes.remove(atOffsets: offsets)
        for index in route.nodes.indices { route.nodes[index].order = index }
        persist()
    }

    private func persist() {
        route.version += 1
        Task { await model.saveRoute(route) }
    }
}
