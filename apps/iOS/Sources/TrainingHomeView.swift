import AVFoundation
import Combine
import DrivingTrainerDomain
import DrivingTrainerLocationKit
import MapKit
import SwiftUI
import UIKit

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

private enum TrainingAudioMode: String, CaseIterable {
    case coaching
    case examSimulation

    var title: String {
        switch self {
        case .coaching: "训练提示"
        case .examSimulation: "模拟考试播报"
        }
    }
}

private struct TrainingPreviewView: View {
    @EnvironmentObject private var model: AppModel
    let route: Route
    @StateObject private var recorder = LocationRecorder()
    @State private var controller: PracticeController
    @State private var lastReminder: ReminderEvent?
    @State private var audioMode: TrainingAudioMode = .coaching
    @State private var announcementEngine = ExamAnnouncementEngine()
    @State private var lastAnnouncement: ExamAnnouncementEvent?
    @State private var isSaving = false
    @State private var cameraPosition: MapCameraPosition
    @State private var visibleCamera: MapCamera?
    private let speaker = AVSpeechSynthesizer()

    init(route: Route) {
        self.route = route
        _controller = State(initialValue: PracticeController(route: route))
        _cameraPosition = State(initialValue: Self.mapPosition(for: route))
    }

    var body: some View {
        VStack(spacing: 0) {
            Map(position: $cameraPosition, interactionModes: [.pan, .zoom]) {
                UserAnnotation()
                if route.path.count >= 2 {
                    MapPolyline(coordinates: route.path.map(\.coordinate.clLocationCoordinate))
                        .stroke(.blue.opacity(0.7), lineWidth: 5)
                }
                ForEach(route.nodes) { node in
                    Marker("\(node.order + 1)", coordinate: node.coordinate.clLocationCoordinate)
                }
                ForEach(route.announcements) { announcement in
                    Marker(
                        "\(announcement.order + 1). \(announcement.project.displayName)",
                        systemImage: "speaker.wave.2.fill",
                        coordinate: announcement.coordinate.clLocationCoordinate
                    )
                    .tint(.orange)
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
            .overlay(alignment: .bottomTrailing) {
                MapZoomButtons { scale in
                    zoomMap(by: scale)
                }
                .padding(12)
            }

            VStack(spacing: 14) {
                if controller.state == .idle {
                    Picker("语音模式", selection: $audioMode) {
                        ForEach(TrainingAudioMode.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                modeStatus

                if audioMode == .coaching, let lastReminder {
                    Text("已提醒：距离节点约 \(Int(lastReminder.distanceMeters)) 米")
                        .font(.caption).foregroundStyle(.secondary)
                }

                if audioMode == .examSimulation, let lastAnnouncement {
                    Text("已播报：\(lastAnnouncement.announcement.project.announcementText)")
                        .font(.caption).foregroundStyle(.secondary)
                }

                controls
            }
            .padding()
            .background(.regularMaterial)
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(controller.state == .active || controller.state == .paused)
        .onAppear { recorder.requestAuthorization() }
        .onAppear {
            model.updateWatch(route: route.name, instruction: "准备开始训练")
        }
        .onReceive(recorder.$latestPoint.compactMap { $0 }) { point in
            guard controller.state == .active else { return }
            let reminder = try? controller.receive(point)
            if audioMode == .coaching, let event = reminder {
                remind(event)
            } else if audioMode == .examSimulation,
                      let event = announcementEngine.evaluate(
                        location: point,
                        announcements: route.announcements
                      ) {
                announceExamProject(event)
            }
        }
    }

    @ViewBuilder
    private var modeStatus: some View {
        if audioMode == .coaching {
            if let node = controller.currentNode {
                VStack(spacing: 5) {
                    Text("下一训练点 · \(node.type.title)").font(.caption).foregroundStyle(.secondary)
                    Text(node.instruction).font(.title3.bold()).multilineTextAlignment(.center)
                }
            } else if controller.state == .active {
                Label("所有训练点已完成", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Text("\(route.name) · \(route.nodes.count) 个训练提示点").font(.headline)
            }
        } else {
            if let nextAnnouncement {
                VStack(spacing: 5) {
                    Text("下一考核项目").font(.caption).foregroundStyle(.secondary)
                    Text(nextAnnouncement.project.displayName).font(.title3.bold())
                }
            } else if controller.state == .active {
                Label("考核项目已全部播报", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Text("\(route.name) · \(route.announcements.count) 个考核播报点").font(.headline)
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch controller.state {
        case .idle:
            Button("开始训练", systemImage: "play.fill") { start() }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(!canStart || !canLocate)
        case .active:
            VStack(spacing: 10) {
                if audioMode == .coaching {
                    HStack {
                        Button("已完成", systemImage: "checkmark") { mark(.completed) }
                            .buttonStyle(.borderedProminent)
                        Button("有困难", systemImage: "exclamationmark.triangle") { mark(.difficult) }
                            .buttonStyle(.bordered)
                        Button("跳过", systemImage: "forward.end") { mark(.skipped) }
                            .buttonStyle(.bordered)
                    }
                    .disabled(controller.currentNode == nil)
                } else {
                    Text("已播报 \(announcementEngine.nextAnnouncementIndex) / \(route.announcements.count)")
                        .font(.subheadline.monospacedDigit())
                }

                HStack {
                    Button("暂停", systemImage: "pause.fill") { pause() }
                        .buttonStyle(.bordered)
                    Button("结束训练", systemImage: "stop.fill") { finish() }
                        .buttonStyle(.bordered)
                }
            }
        case .paused:
            HStack {
                Button("继续训练", systemImage: "play.fill") { resume() }
                    .buttonStyle(.borderedProminent)
                Button("结束训练", systemImage: "stop.fill") { finish() }
                    .buttonStyle(.bordered)
            }
        case .finished:
            Label("训练记录已保存", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        }
    }

    private var canLocate: Bool {
        recorder.authorizationStatus == .authorizedWhenInUse || recorder.authorizationStatus == .authorizedAlways
    }

    private var canStart: Bool {
        switch audioMode {
        case .coaching: !route.nodes.isEmpty
        case .examSimulation: !route.announcements.isEmpty
        }
    }

    private var nextAnnouncement: ExamAnnouncement? {
        guard announcementEngine.nextAnnouncementIndex < route.announcements.count else { return nil }
        return route.announcements[announcementEngine.nextAnnouncementIndex]
    }

    private var navigationTitle: String {
        switch controller.state {
        case .active: "训练中"
        case .paused: "训练已暂停"
        case .idle, .finished: "训练准备"
        }
    }

    private static func mapPosition(for route: Route) -> MapCameraPosition {
        guard !route.path.isEmpty || !route.nodes.isEmpty || !route.announcements.isEmpty else {
            return .userLocation(followsHeading: false, fallback: .automatic)
        }

        let coordinates = route.path.map(\.coordinate.clLocationCoordinate)
            + route.nodes.map(\.coordinate.clLocationCoordinate)
            + route.announcements.map(\.coordinate.clLocationCoordinate)
        let points = coordinates.map(MKMapPoint.init)
        guard let firstPoint = points.first else { return .automatic }

        var rect = MKMapRect(origin: firstPoint, size: MKMapSize(width: 1, height: 1))
        for point in points.dropFirst() {
            rect = rect.union(MKMapRect(origin: point, size: MKMapSize(width: 1, height: 1)))
        }

        let horizontalPadding = max(rect.size.width * 0.15, 500)
        let verticalPadding = max(rect.size.height * 0.15, 500)
        return .rect(rect.insetBy(dx: -horizontalPadding, dy: -verticalPadding))
    }

    private func start() {
        try? controller.start()
        announcementEngine.reset()
        lastAnnouncement = nil
        recorder.start()
        switch audioMode {
        case .coaching:
            speak("开始训练。前方第一个训练点：\(controller.currentNode?.instruction ?? "请按路线行驶")")
            model.updateWatch(route: route.name, instruction: controller.currentNode?.instruction ?? "请按路线行驶")
        case .examSimulation:
            model.updateWatch(route: route.name, instruction: "模拟考试播报已就绪")
        }
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

    private func resume() {
        try? controller.resume()
        recorder.resume()
    }

    private func pause() {
        try? controller.pause()
        recorder.pause()
        if audioMode == .coaching { speak("训练已暂停") }
        model.updateWatch(route: route.name, instruction: "训练已暂停")
    }

    private func mark(_ outcome: AttemptOutcome) {
        try? controller.markCurrentNode(outcome)
        UINotificationFeedbackGenerator().notificationOccurred(outcome == .completed ? .success : .warning)
        if let next = controller.currentNode {
            speak("下一节点：\(next.instruction)")
            model.updateWatch(route: route.name, instruction: next.instruction)
        } else {
            model.updateWatch(route: route.name, instruction: "所有节点已完成", alert: true)
        }
    }

    private func remind(_ event: ReminderEvent) {
        lastReminder = event
        speak(event.node.instruction)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        model.updateWatch(route: route.name, instruction: event.node.instruction, alert: true)
    }

    private func announceExamProject(_ event: ExamAnnouncementEvent) {
        lastAnnouncement = event
        let text = event.announcement.project.announcementText
        speak(text)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        model.updateWatch(route: route.name, instruction: text, alert: true)
    }

    private func finish() {
        recorder.stop()
        guard let session = try? controller.finish() else { return }
        isSaving = true
        Task {
            await model.save(session)
            isSaving = false
        }
    }

    private func speak(_ text: String) {
        speaker.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.48
        speaker.speak(utterance)
    }
}

private extension Coordinate {
    var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
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
                Text("\(route.venue) · \(route.nodes.count) 个训练点 · \(route.announcements.count) 个考核项")
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
