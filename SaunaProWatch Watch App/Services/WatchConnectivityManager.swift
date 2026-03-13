import Foundation
import WatchConnectivity

@Observable
final class WatchConnectivityManager: NSObject {
    static let shared = WatchConnectivityManager()

    var isReachable = false

    private var wcSession: WCSession?

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        wcSession = session
    }

    func sendSession(_ sessionData: WatchSessionData) {
        guard let session = wcSession else {
            queueSession(sessionData)
            return
        }

        guard let data = try? JSONEncoder().encode(sessionData) else { return }

        if session.isReachable {
            session.sendMessage(["sessionData": data], replyHandler: { _ in
                // Success
            }, errorHandler: { [weak self] _ in
                self?.sendSessionBackground(sessionData)
            })
        } else {
            sendSessionBackground(sessionData)
        }
    }

    func sendPendingSessions() {
        let pending = loadPendingSessions()
        guard !pending.isEmpty else { return }

        clearPendingSessions()

        for session in pending {
            sendSession(session)
        }
    }

    // MARK: - Background Transfer (guaranteed delivery)

    private func sendSessionBackground(_ sessionData: WatchSessionData) {
        guard let session = wcSession,
              let data = try? JSONEncoder().encode(sessionData) else {
            queueSession(sessionData)
            return
        }

        session.transferUserInfo(["sessionData": data])
    }

    // MARK: - Pending Queue (UserDefaults)

    private func queueSession(_ sessionData: WatchSessionData) {
        var pending = loadPendingSessions()
        pending.append(sessionData)
        savePendingSessions(pending)
    }

    private func loadPendingSessions() -> [WatchSessionData] {
        guard let data = UserDefaults.standard.data(forKey: "pendingSessions"),
              let sessions = try? JSONDecoder().decode([WatchSessionData].self, from: data) else {
            return []
        }
        return sessions
    }

    private func savePendingSessions(_ sessions: [WatchSessionData]) {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: "pendingSessions")
        }
    }

    private func clearPendingSessions() {
        UserDefaults.standard.removeObject(forKey: "pendingSessions")
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                              activationDidCompleteWith activationState: WCSessionActivationState,
                              error: Error?) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            if activationState == .activated {
                self.sendPendingSessions()
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            if session.isReachable {
                self.sendPendingSessions()
            }
        }
    }
}
