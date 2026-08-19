import DrivingTrainerDomain
import MapKit
import SwiftUI

struct RoutesView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showsAppleMapsImporter = false

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
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showsAppleMapsImporter = true
                } label: {
                    Label("从 Apple 地图导入", systemImage: "square.and.arrow.down")
                }

                NavigationLink {
                    RecordingView()
                } label: {
                    Label("录制", systemImage: "record.circle")
                }
            }
        }
        .sheet(isPresented: $showsAppleMapsImporter) {
            AppleMapsImportView(routes: model.routes) { route in
                await model.saveRoute(route)
            }
        }
    }
}

private struct AppleMapsImportView: View {
    @Environment(\.dismiss) private var dismiss
    let routes: [Route]
    let onImport: (Route) async -> Void

    @State private var selectedRouteID: UUID?
    @State private var sharedLink = ""
    @State private var isImporting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("导入到考试路线") {
                    Picker("目标路线", selection: $selectedRouteID) {
                        Text("请选择").tag(nil as UUID?)
                        ForEach(routes) { route in
                            Text(route.name).tag(route.id as UUID?)
                        }
                    }
                }

                Section("Apple 地图路线链接") {
                    TextField("粘贴 maps.apple.com 路线链接", text: $sharedLink, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Text("在 Apple 地图中打开路线，点击共享并复制链接。导入会更新路线轨迹，已经编辑的考试节点不会被删除。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        importRoute()
                    } label: {
                        if isImporting {
                            HStack {
                                ProgressView()
                                Text("正在读取 Apple 路线…")
                            }
                        } else {
                            Label("导入路线", systemImage: "map.fill")
                        }
                    }
                    .disabled(selectedRouteID == nil || sharedLink.isEmpty || isImporting)
                }
            }
            .navigationTitle("从 Apple 地图导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private func importRoute() {
        guard
            let selectedRouteID,
            var route = routes.first(where: { $0.id == selectedRouteID })
        else { return }

        isImporting = true
        errorMessage = nil

        Task {
            do {
                let importedPath = try await AppleMapsRouteImporter.importPath(from: sharedLink)
                route.path = importedPath
                route.version += 1
                await onImport(route)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isImporting = false
            }
        }
    }
}

private enum AppleMapsRouteImporter {
    static func importPath(from link: String) async throws -> [TrackPoint] {
        guard let originalURL = URL(string: link.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw ImportError.invalidLink
        }

        guard isAppleMapsHost(originalURL.host) else {
            throw ImportError.notAppleMapsLink
        }

        let resolvedURL = try await resolveShortLink(originalURL)
        guard let components = URLComponents(url: resolvedURL, resolvingAgainstBaseURL: false) else {
            throw ImportError.invalidLink
        }

        let parameters = Dictionary(
            components.queryItems?.map { ($0.name.lowercased(), $0.value ?? "") } ?? [],
            uniquingKeysWith: { _, newest in newest }
        )
        guard
            let sourceValue = parameters["source"] ?? parameters["saddr"],
            let destinationValue = parameters["destination"] ?? parameters["daddr"],
            !sourceValue.isEmpty,
            !destinationValue.isEmpty
        else {
            throw ImportError.missingEndpoints
        }

        async let source = mapItem(from: sourceValue)
        async let destination = mapItem(from: destinationValue)

        let request = MKDirections.Request()
        request.source = try await source
        request.destination = try await destination
        request.transportType = .automobile
        request.requestsAlternateRoutes = false

        let response = try await MKDirections(request: request).calculate()
        guard let appleRoute = response.routes.first else {
            throw ImportError.routeNotFound
        }
        return trackPoints(from: appleRoute.polyline)
    }

    private static func resolveShortLink(_ url: URL) async throws -> URL {
        guard url.host?.hasSuffix("maps.apple") == true else { return url }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (_, response) = try await URLSession.shared.data(for: request)
        return response.url ?? url
    }

    private static func mapItem(from value: String) async throws -> MKMapItem {
        if let coordinate = coordinate(from: value) {
            return MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = value
        let response = try await MKLocalSearch(request: request).start()
        guard let item = response.mapItems.first else { throw ImportError.placeNotFound(value) }
        return item
    }

    private static func coordinate(from value: String) -> CLLocationCoordinate2D? {
        let parts = value.split(separator: ",", maxSplits: 1).map(String.init)
        guard
            parts.count == 2,
            let latitude = Double(parts[0]),
            let longitude = Double(parts[1]),
            (-90...90).contains(latitude),
            (-180...180).contains(longitude)
        else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private static func trackPoints(from polyline: MKPolyline) -> [TrackPoint] {
        var coordinates = [CLLocationCoordinate2D](
            repeating: CLLocationCoordinate2D(),
            count: polyline.pointCount
        )
        polyline.getCoordinates(&coordinates, range: NSRange(location: 0, length: polyline.pointCount))

        let step = max(1, coordinates.count / 2_000)
        var sampled = stride(from: 0, to: coordinates.count, by: step).map { index in
            TrackPoint(
                coordinate: Coordinate(
                    latitude: coordinates[index].latitude,
                    longitude: coordinates[index].longitude
                ),
                horizontalAccuracy: 0
            )
        }
        if let last = coordinates.last, coordinates.count > 1 {
            let endPoint = TrackPoint(
                coordinate: Coordinate(latitude: last.latitude, longitude: last.longitude),
                horizontalAccuracy: 0
            )
            if sampled.last?.coordinate != endPoint.coordinate { sampled.append(endPoint) }
        }
        return sampled
    }

    private static func isAppleMapsHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return host == "maps.apple.com" || host.hasSuffix(".maps.apple.com") || host.hasSuffix("maps.apple")
    }

    private enum ImportError: LocalizedError {
        case invalidLink
        case notAppleMapsLink
        case missingEndpoints
        case placeNotFound(String)
        case routeNotFound

        var errorDescription: String? {
            switch self {
            case .invalidLink:
                "链接格式不正确。"
            case .notAppleMapsLink:
                "请粘贴 Apple 地图分享的链接。"
            case .missingEndpoints:
                "链接没有同时包含起点和终点。请在 Apple 地图路线页面重新复制分享链接。"
            case let .placeNotFound(place):
                "Apple 地图无法识别地点：\(place)"
            case .routeNotFound:
                "Apple 地图没有返回可驾驶路线。"
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
