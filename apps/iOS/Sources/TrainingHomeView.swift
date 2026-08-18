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

private struct TrainingPreviewView: View {
    @EnvironmentObject private var model: AppModel
    let route: Route
    @StateObject private var recorder = LocationRecorder()
    @State private var controller: PracticeController
    @State private var lastReminder: ReminderEvent?
    @State private var isSaving = false
    private let speaker = AVSpeechSynthesizer()

    init(route: Route) {
        self.route = route
        _controller = State(initialValue: PracticeController(route: route))
    }

    var body: some View {
        VStack(spacing: 0) {
            Map {
                UserAnnotation()
                if route.path.count >= 2 {
                    MapPolyline(coordinates: route.path.map(\.coordinate.clLocationCoordinate))
                        .stroke(.blue.opacity(0.7), lineWidth: 5)
                }
                ForEach(route.nodes) { node in
                    Marker("\(node.order + 1)", coordinate: node.coordinate.clLocationCoordinate)
                }
            }
            .mapControls { MapUserLocationButton() }

            VStack(spacing: 14) {
                if let node = controller.currentNode {
                    VStack(spacing: 5) {
                        Text("下一节点 · \(node.type.title)").font(.caption).foregroundStyle(.secondary)
                        Text(node.instruction).font(.title3.bold()).multilineTextAlignment(.center)
                    }
                } else if controller.state == .active {
                    Label("所有节点已完成", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                } else {
                    Text("\(route.name) · \(route.nodes.count) 个训练节点").font(.headline)
                }

                if let lastReminder {
                    Text("已提醒：距离节点约 \(Int(lastReminder.distanceMeters)) 米")
                        .font(.caption).foregroundStyle(.secondary)
                }

                controls
            }
            .padding()
            .background(.regularMaterial)
        }
        .navigationTitle(controller.state == .active ? "训练中" : "训练准备")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(controller.state == .active || controller.state == .paused)
        .onAppear { recorder.requestAuthorization() }
        .onAppear {
            model.updateWatch(route: route.name, instruction: controller.currentNode?.instruction ?? "准备开始训练")
        }
        .onReceive(recorder.$latestPoint.compactMap { $0 }) { point in
            guard controller.state == .active else { return }
            if let event = try? controller.receive(point) {
                remind(event)
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch controller.state {
        case .idle:
            Button("开始训练", systemImage: "play.fill") { start() }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(route.nodes.isEmpty || !canLocate)
        case .active:
            HStack {
                Button("已完成", systemImage: "checkmark") { mark(.completed) }
                    .buttonStyle(.borderedProminent)
                    .disabled(controller.currentNode == nil)
                Button("有困难", systemImage: "exclamationmark.triangle") { mark(.difficult) }
                    .buttonStyle(.bordered)
                    .disabled(controller.currentNode == nil)
                Button("结束", systemImage: "stop.fill") { finish() }
                    .buttonStyle(.bordered)
            }
        case .paused:
            Button("继续训练", systemImage: "play.fill") { resume() }.buttonStyle(.borderedProminent)
        case .finished:
            Label("训练记录已保存", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        }
    }

    private var canLocate: Bool {
        recorder.authorizationStatus == .authorizedWhenInUse || recorder.authorizationStatus == .authorizedAlways
    }

    private func start() {
        try? controller.start()
        recorder.start()
        speak("开始训练。前方第一个节点：\(controller.currentNode?.instruction ?? "请按路线行驶")")
        model.updateWatch(route: route.name, instruction: controller.currentNode?.instruction ?? "请按路线行驶")
    }

    private func resume() {
        try? controller.resume()
        recorder.resume()
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
