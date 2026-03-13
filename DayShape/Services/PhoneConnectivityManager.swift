import Foundation
import WatchConnectivity

extension Notification.Name {
    static let watchSessionReceived = Notification.Name("watchSessionReceived")
}

@Observable
final class PhoneConnectivityManager: NSObject {
    static let shared = PhoneConnectivityManager()

    var isPaired = false
    var isReachable = false
    var lastReceivedSession: WatchSessionData?

    private var wcSession: WCSession?

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        wcSession = session
    }

    private func handleReceivedSessionData(_ data: Data) {
        guard let sessionData = try? JSONDecoder().decode(WatchSessionData.self, from: data) else { return }
        lastReceivedSession = sessionData
        NotificationCenter.default.post(name: .watchSessionReceived, object: sessionData)
    }
}

// MARK: - WCSessionDelegate

extension PhoneConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                              activationDidCompleteWith activationState: WCSessionActivationState,
                              error: Error?) {
        Task { @MainActor in
            self.isPaired = session.isPaired
            self.isReachable = session.isReachable
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }

    // Foreground message from watch
    nonisolated func session(_ session: WCSession,
                              didReceiveMessage message: [String: Any],
                              replyHandler: @escaping ([String: Any]) -> Void) {
        if let data = message["sessionData"] as? Data {
            Task { @MainActor in
                self.handleReceivedSessionData(data)
            }
            replyHandler(["status": "ok"])
        }
    }

    // Background transfer from watch
    nonisolated func session(_ session: WCSession,
                              didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if let data = userInfo["sessionData"] as? Data {
            Task { @MainActor in
                self.handleReceivedSessionData(data)
            }
        }
    }
}
