import Combine
import SwiftUI
import WatchConnectivity
import WatchKit

@main
struct DrivingTrainerWatchApp: App {
    @StateObject private var bridge = WatchSessionBridge()

    var body: some Scene {
        WindowGroup { WatchHomeView().environmentObject(bridge) }
    }
}

private struct WatchHomeView: View {
    @EnvironmentObject private var bridge: WatchSessionBridge

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "steeringwheel")
                .font(.largeTitle)
                .foregroundStyle(.blue)
            Text(bridge.route).font(.headline)
            Text(bridge.instruction)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

@MainActor
private final class WatchSessionBridge: NSObject, ObservableObject {
    @Published var route = "驾考训练"
    @Published var instruction = "等待 iPhone 开始训练"

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    private func apply(_ payload: [String: Any]) {
        route = payload["route"] as? String ?? route
        instruction = payload["instruction"] as? String ?? instruction
        if payload["alert"] as? Bool == true {
            WKInterfaceDevice.current().play(.notification)
        }
    }
}

extension WatchSessionBridge: @preconcurrency WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.apply(applicationContext) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.apply(message) }
    }
}
