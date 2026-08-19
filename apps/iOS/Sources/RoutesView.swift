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

                    Text("在 Apple 地图中打开路线，点击共享并复制链接。导入只更新路线轨迹，已有训练提示点和考核项目不会被删除。")
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
    @State private var editingAnnouncement: ExamAnnouncement?
    @State private var selectedCoordinate: Coordinate?

    init(route: Route) { _route = State(initialValue: route) }

    var body: some View {
        List {
            if !route.path.isEmpty || !route.nodes.isEmpty || !route.announcements.isEmpty {
                RouteDetailMap(
                    route: route,
                    selectedCoordinate: selectedCoordinate,
                    onSelectCoordinate: { selectedCoordinate = $0 }
                )
                    .frame(height: 260)
                    .listRowInsets(EdgeInsets())

                Section("停车后补充路线点") {
                    if let selectedCoordinate {
                        Text("已选择地图位置：\(selectedCoordinate.latitude, specifier: "%.5f"), \(selectedCoordinate.longitude, specifier: "%.5f")")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            Button("添加训练提示", systemImage: "mappin.and.ellipse") {
                                prepareTrainingNode(at: selectedCoordinate)
                            }
                            .buttonStyle(.bordered)

                            Button("添加考核项目", systemImage: "speaker.wave.2") {
                                prepareExamAnnouncement(at: selectedCoordinate)
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        Label("点击上方地图选择位置，再添加训练提示或考核项目。", systemImage: "hand.tap")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !route.nodes.isEmpty {
                Section("训练提示点") {
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
                    .onMove(perform: moveNodes)
                }
            }

            if !route.announcements.isEmpty {
                Section("模拟考试播报点") {
                    ForEach(route.announcements) { announcement in
                        Button {
                            editingAnnouncement = announcement
                        } label: {
                            HStack {
                                Text("\(announcement.order + 1)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.orange)
                                    .frame(width: 28, height: 28)
                                    .background(.orange.opacity(0.12), in: Circle())
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(announcement.project.displayName)
                                        .font(.headline).foregroundStyle(.primary)
                                    Text("“\(announcement.project.announcementText)” · 提前 \(Int(announcement.triggerRadiusMeters)) 米")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteAnnouncements)
                    .onMove(perform: moveAnnouncements)
                }
            }
        }
        .navigationTitle(route.name)
        .toolbar { EditButton() }
        .overlay {
            if route.nodes.isEmpty && route.announcements.isEmpty && route.path.isEmpty {
                ContentUnavailableView(
                    "尚未设置路线内容",
                    systemImage: "map",
                    description: Text("录制路线后可分别添加训练提示点和模拟考试播报点。")
                )
            }
        }
        .sheet(item: $editingNode) { node in
            NodeEditorView(node: node) { updated in
                if let index = route.nodes.firstIndex(where: { $0.id == updated.id }) {
                    route.nodes[index] = updated
                } else {
                    route.nodes.append(updated)
                }
                selectedCoordinate = nil
                persist()
            }
        }
        .sheet(item: $editingAnnouncement) { announcement in
            ExamAnnouncementEditorView(announcement: announcement) { updated in
                if let index = route.announcements.firstIndex(where: { $0.id == updated.id }) {
                    route.announcements[index] = updated
                } else {
                    route.announcements.append(updated)
                }
                selectedCoordinate = nil
                persist()
            }
        }
    }

    private func deleteNodes(at offsets: IndexSet) {
        route.nodes.remove(atOffsets: offsets)
        for index in route.nodes.indices { route.nodes[index].order = index }
        persist()
    }

    private func deleteAnnouncements(at offsets: IndexSet) {
        route.announcements.remove(atOffsets: offsets)
        for index in route.announcements.indices { route.announcements[index].order = index }
        persist()
    }

    private func moveNodes(from source: IndexSet, to destination: Int) {
        route.nodes.move(fromOffsets: source, toOffset: destination)
        for index in route.nodes.indices { route.nodes[index].order = index }
        persist()
    }

    private func moveAnnouncements(from source: IndexSet, to destination: Int) {
        route.announcements.move(fromOffsets: source, toOffset: destination)
        for index in route.announcements.indices { route.announcements[index].order = index }
        persist()
    }

    private func prepareTrainingNode(at coordinate: Coordinate) {
        editingNode = RouteNode(
            coordinate: coordinate,
            order: route.nodes.count,
            type: .custom,
            instruction: "前方训练提示点"
        )
    }

    private func prepareExamAnnouncement(at coordinate: Coordinate) {
        editingAnnouncement = ExamAnnouncement(
            coordinate: coordinate,
            order: route.announcements.count,
            project: .start
        )
    }

    private func persist() {
        route.version += 1
        Task { await model.saveRoute(route) }
    }
}

private struct RouteDetailMap: View {
    let route: Route
    let selectedCoordinate: Coordinate?
    let onSelectCoordinate: (Coordinate) -> Void
    @State private var cameraPosition: MapCameraPosition

    init(
        route: Route,
        selectedCoordinate: Coordinate?,
        onSelectCoordinate: @escaping (Coordinate) -> Void
    ) {
        self.route = route
        self.selectedCoordinate = selectedCoordinate
        self.onSelectCoordinate = onSelectCoordinate
        _cameraPosition = State(initialValue: Self.mapPosition(for: route))
    }

    var body: some View {
        MapReader { proxy in
            Map(position: $cameraPosition, interactionModes: [.pan, .zoom]) {
                if route.path.count >= 2 {
                    MapPolyline(coordinates: route.path.map { Self.coordinate($0.coordinate) })
                        .stroke(.blue, lineWidth: 5)
                }
                ForEach(route.nodes) { node in
                    Marker("\(node.order + 1)", coordinate: Self.coordinate(node.coordinate))
                }
                ForEach(route.announcements) { announcement in
                    Marker(
                        "\(announcement.order + 1). \(announcement.project.displayName)",
                        systemImage: "speaker.wave.2.fill",
                        coordinate: Self.coordinate(announcement.coordinate)
                    )
                    .tint(.orange)
                }
                if let selectedCoordinate {
                    Marker(
                        "已选位置",
                        systemImage: "scope",
                        coordinate: Self.coordinate(selectedCoordinate)
                    )
                    .tint(.purple)
                }
            }
            .mapStyle(.standard)
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .onTapGesture { position in
                guard let coordinate = proxy.convert(position, from: .local) else { return }
                onSelectCoordinate(
                    Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private static func mapPosition(for route: Route) -> MapCameraPosition {
        let coordinates = route.path.map { coordinate($0.coordinate) }
            + route.nodes.map { coordinate($0.coordinate) }
            + route.announcements.map { coordinate($0.coordinate) }
        let points = coordinates.map(MKMapPoint.init)
        guard let first = points.first else { return .automatic }

        var rect = MKMapRect(origin: first, size: MKMapSize(width: 1, height: 1))
        for point in points.dropFirst() {
            rect = rect.union(MKMapRect(origin: point, size: MKMapSize(width: 1, height: 1)))
        }
        let horizontalPadding = max(rect.size.width * 0.15, 500)
        let verticalPadding = max(rect.size.height * 0.15, 500)
        return .rect(rect.insetBy(dx: -horizontalPadding, dy: -verticalPadding))
    }

    private static func coordinate(_ coordinate: Coordinate) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}
