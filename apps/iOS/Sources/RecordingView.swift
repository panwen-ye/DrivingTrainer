import CoreLocation
import DrivingTrainerDomain
import DrivingTrainerLocationKit
import MapKit
import SwiftUI

struct RecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel
    @StateObject private var recorder = LocationRecorder()
    @State private var routeName = "新路线"
    @State private var isSaving = false
    @State private var nodes: [RouteNode] = []
    @State private var editingNode: RouteNode?
    @State private var cameraPosition: MapCameraPosition = .userLocation(
        followsHeading: false,
        fallback: .automatic
    )
    @State private var visibleCamera: MapCamera?

    var body: some View {
        VStack(spacing: 0) {
            map
            statusPanel
        }
        .navigationTitle("路线录制")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(recorder.state != .idle)
        .onAppear { recorder.requestAuthorization() }
        .sheet(item: $editingNode) { node in
            NodeEditorView(node: node) { updated in
                guard let index = nodes.firstIndex(where: { $0.id == updated.id }) else { return }
                nodes[index] = updated
            }
        }
    }

    private var map: some View {
        Map(position: $cameraPosition, interactionModes: [.pan, .zoom]) {
            UserAnnotation()
            if coordinates.count >= 2 {
                MapPolyline(coordinates: coordinates)
                    .stroke(.blue, lineWidth: 5)
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
        .mapControlVisibility(.visible)
        .mapStyle(.standard)
        .onMapCameraChange(frequency: .continuous) { context in
            visibleCamera = context.camera
        }
        .frame(maxHeight: .infinity)
        .overlay(alignment: .top) {
            permissionBanner
        }
        .overlay(alignment: .trailing) {
            MapZoomButtons { scale in
                zoomMap(by: scale)
            }
            .padding(.trailing, 10)
        }
    }

    private var statusPanel: some View {
        VStack(spacing: 14) {
            if recorder.state == .idle {
                TextField("路线名称", text: $routeName)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                metric(title: "距离", value: distanceText)
                Divider().frame(height: 36)
                metric(title: "轨迹点", value: "\(recorder.track.count)")
                Divider().frame(height: 36)
                metric(title: "节点", value: "\(nodes.count)")
            }

            if recorder.state != .idle {
                Button("标记考试节点", systemImage: "mappin.and.ellipse") { addNode() }
                    .buttonStyle(.bordered)
                    .disabled(recorder.latestPoint == nil)
            }

            switch recorder.state {
            case .idle:
                Button("开始录制", systemImage: "record.circle") {
                    recorder.start()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canRecord)
            case .recording:
                HStack {
                    Button("暂停", systemImage: "pause.fill") { recorder.pause() }
                        .buttonStyle(.bordered)
                    Button("结束并保存", systemImage: "stop.fill") { saveRecording() }
                        .buttonStyle(.borderedProminent)
                }
                .controlSize(.large)
            case .paused:
                HStack {
                    Button("继续", systemImage: "play.fill") { recorder.resume() }
                        .buttonStyle(.bordered)
                    Button("结束并保存", systemImage: "stop.fill") { saveRecording() }
                        .buttonStyle(.borderedProminent)
                }
                .controlSize(.large)
            }
        }
        .padding()
        .background(.regularMaterial)
        .disabled(isSaving)
    }

    @ViewBuilder
    private var permissionBanner: some View {
        switch recorder.authorizationStatus {
        case .denied, .restricted:
            Label("定位权限未开启，请在系统设置中允许使用 App 期间定位", systemImage: "location.slash")
                .font(.footnote)
                .padding(10)
                .background(.red.opacity(0.9), in: Capsule())
                .foregroundStyle(.white)
                .padding()
        case .notDetermined:
            Label("正在请求定位权限", systemImage: "location")
                .font(.footnote)
                .padding(10)
                .background(.thinMaterial, in: Capsule())
                .padding()
        default:
            EmptyView()
        }
    }

    private var canRecord: Bool {
        recorder.authorizationStatus == .authorizedWhenInUse
            || recorder.authorizationStatus == .authorizedAlways
    }

    private var coordinates: [CLLocationCoordinate2D] {
        recorder.track.map {
            CLLocationCoordinate2D(
                latitude: $0.coordinate.latitude,
                longitude: $0.coordinate.longitude
            )
        }
    }

    private var distanceText: String {
        let meters = zip(recorder.track, recorder.track.dropFirst()).reduce(0.0) { result, pair in
            result + GeoDistance.meters(from: pair.0.coordinate, to: pair.1.coordinate)
        }
        return meters < 1_000
            ? "\(Int(meters)) m"
            : String(format: "%.1f km", meters / 1_000)
    }

    private var accuracyText: String {
        guard let accuracy = recorder.latestPoint?.horizontalAccuracy else { return "--" }
        return "±\(Int(accuracy)) m"
    }

    private func metric(title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.headline.monospacedDigit())
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func saveRecording() {
        let track = recorder.stop()
        guard !track.isEmpty else { return }
        isSaving = true
        let route = Route(
            name: routeName,
            venue: "武汉同心考场",
            path: track,
            nodes: nodes
        )
        Task {
            await model.saveRoute(route)
            isSaving = false
            dismiss()
        }
    }

    private func addNode() {
        guard let point = recorder.latestPoint else { return }
        let node = RouteNode(
            coordinate: point.coordinate,
            order: nodes.count,
            type: .custom,
            instruction: "前方考试节点"
        )
        nodes.append(node)
        editingNode = node
    }

    private func zoomMap(by scale: Double) {
        guard let camera = visibleCamera else { return }
        let distance = min(max(camera.distance * scale, 40), 20_000_000)
        let updatedCamera = MapCamera(
            centerCoordinate: camera.centerCoordinate,
            distance: distance,
            heading: camera.heading,
            pitch: camera.pitch
        )
        visibleCamera = updatedCamera
        cameraPosition = .camera(updatedCamera)
    }
}

struct MapZoomButtons: View {
    let onZoom: (Double) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button {
                onZoom(0.5)
            } label: {
                Image(systemName: "plus")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("放大地图")

            Divider()

            Button {
                onZoom(2)
            } label: {
                Image(systemName: "minus")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("缩小地图")
        }
        .buttonStyle(.plain)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10).stroke(.quaternary)
        }
    }
}

struct NodeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var node: RouteNode
    let onSave: (RouteNode) -> Void

    init(node: RouteNode, onSave: @escaping (RouteNode) -> Void) {
        _node = State(initialValue: node)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("节点类型", selection: $node.type) {
                    ForEach(NodeType.allCases, id: \.self) { type in
                        Text(type.title).tag(type)
                    }
                }
                TextField("语音提醒内容", text: $node.instruction, axis: .vertical)
                Stepper(value: $node.reminderRadiusMeters, in: 40...300, step: 20) {
                    LabeledContent("提醒距离", value: "\(Int(node.reminderRadiusMeters)) 米")
                }
            }
            .navigationTitle("编辑节点")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(node)
                        dismiss()
                    }
                    .disabled(node.instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

extension NodeType {
    var title: String {
        switch self {
        case .start: "起步"
        case .trafficLight: "路口/信号灯"
        case .turnLeft: "左转"
        case .turnRight: "右转"
        case .laneChange: "变更车道"
        case .overtake: "超车"
        case .school: "学校区域"
        case .busStop: "公交站"
        case .meeting: "会车"
        case .straightDriving: "直线行驶"
        case .speedControl: "加减挡"
        case .uTurn: "掉头"
        case .pullOver: "靠边停车"
        case .custom: "自定义"
        }
    }
}
