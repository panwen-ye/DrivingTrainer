import Combine
import Foundation
import WatchConnectivity

final class WatchBridge: NSObject, ObservableObject {
    private var session: WCSession? = WCSession.isSupported() ? .default : nil

    override init() {
        super.init()
        session?.delegate = self
        session?.activate()
    }

    func update(route: String, instruction: String, shouldAlert: Bool) {
        guard let session else { return }
        let payload: [String: Any] = [
            "route": route,
            "instruction": instruction,
            "alert": shouldAlert,
            "updatedAt": Date().timeIntervalSince1970
        ]
        try? session.updateApplicationContext(payload)
        if shouldAlert, session.isReachable {
            session.sendMessage(payload, replyHandler: nil)
        }
    }
}

extension WatchBridge: @preconcurrency WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
