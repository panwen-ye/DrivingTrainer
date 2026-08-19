import CoreLocation
import DrivingTrainerDomain
import DrivingTrainerLocationKit
import MapKit
import SwiftUI
import UIKit

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
        .background {
            MapScrollWheelZoomHandler { scale in
                zoomMap(by: scale)
            }
        }
        .onMapCameraChange(frequency: .continuous) { context in
            visibleCamera = context.camera
        }
        .frame(maxHeight: .infinity)
        .overlay(alignment: .top) {
            permissionBanner
        }
        .overlay(alignment: .bottomTrailing) {
            MapZoomButtons { scale in
                zoomMap(by: scale)
            }
            .padding(12)
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
        withAnimation(.easeOut(duration: 0.18)) {
            cameraPosition = .camera(updatedCamera)
        }
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
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 42, height: 38)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("放大地图")
            .accessibilityHint("也可以双指张开或使用鼠标滚轮向上滚动")
            .buttonRepeatBehavior(.enabled)

            Divider()
                .padding(.horizontal, 8)

            Button {
                onZoom(2)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 42, height: 38)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("缩小地图")
            .accessibilityHint("也可以双指捏合或使用鼠标滚轮向下滚动")
            .buttonRepeatBehavior(.enabled)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .fixedSize()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(.primary.opacity(0.12), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.16), radius: 4, y: 2)
    }
}

struct MapScrollWheelZoomHandler: UIViewRepresentable {
    let onZoom: (Double) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onZoom: onZoom)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        DispatchQueue.main.async {
            context.coordinator.attach(toMapNear: view)
        }
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.onZoom = onZoom
        DispatchQueue.main.async {
            context.coordinator.attach(toMapNear: view)
        }
    }

    static func dismantleUIView(_ view: UIView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onZoom: (Double) -> Void
        private weak var mapView: MKMapView?
        private var scrollRecognizer: UIPanGestureRecognizer?

        init(onZoom: @escaping (Double) -> Void) {
            self.onZoom = onZoom
        }

        func attach(toMapNear marker: UIView) {
            guard mapView == nil, let mapView = findMapView(near: marker) else { return }

            let recognizer = UIPanGestureRecognizer(target: self, action: #selector(handleScroll(_:)))
            recognizer.allowedScrollTypesMask = [.continuous, .discrete]
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            mapView.addGestureRecognizer(recognizer)

            self.mapView = mapView
            scrollRecognizer = recognizer
        }

        func detach() {
            if let scrollRecognizer { mapView?.removeGestureRecognizer(scrollRecognizer) }
            scrollRecognizer = nil
            mapView = nil
        }

        @objc private func handleScroll(_ recognizer: UIPanGestureRecognizer) {
            guard recognizer.state == .changed else { return }
            let verticalMovement = recognizer.translation(in: recognizer.view).y
            guard abs(verticalMovement) >= 8 else { return }

            onZoom(verticalMovement < 0 ? 0.5 : 2)
            recognizer.setTranslation(.zero, in: recognizer.view)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        private func findMapView(near marker: UIView) -> MKMapView? {
            var ancestor = marker.superview
            while let view = ancestor {
                if let mapView = findMapView(in: view) { return mapView }
                ancestor = view.superview
            }
            return nil
        }

        private func findMapView(in view: UIView) -> MKMapView? {
            if let mapView = view as? MKMapView { return mapView }
            for subview in view.subviews where subview !== view {
                if let mapView = findMapView(in: subview) { return mapView }
            }
            return nil
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
