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

    var body: some View {
        VStack(spacing: 0) {
            map
            statusPanel
        }
        .navigationTitle("路线录制")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(recorder.state != .idle)
        .onAppear { recorder.requestAuthorization() }
    }

    private var map: some View {
        Map {
            UserAnnotation()
            if coordinates.count >= 2 {
                MapPolyline(coordinates: coordinates)
                    .stroke(.blue, lineWidth: 5)
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .frame(maxHeight: .infinity)
        .overlay(alignment: .top) {
            permissionBanner
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
                metric(title: "GPS", value: accuracyText)
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
            path: track
        )
        Task {
            await model.saveRoute(route)
            isSaving = false
            dismiss()
        }
    }
}
