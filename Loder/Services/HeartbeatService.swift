import Foundation

class HeartbeatService {
    static let shared = HeartbeatService()
    private let api = APIClient.shared
    private var timer: Timer?
    private let interval: TimeInterval = 5.0

    private init() {}

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
        // Send immediately
        sendHeartbeat()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func sendHeartbeat() {
        guard let userId = AppState.shared.currentUser?.id,
              let roomId = AppState.shared.currentRoom?.id else {
            return
        }

        let activeApp = AppState.shared.activeApp

        Task {
            do {
                var body: [String: Any] = ["userId": userId]
                if let app = activeApp {
                    body["activeApp"] = app
                }

                let response: HeartbeatResponse = try await api.request(
                    endpoint: "/rooms/\(roomId)/heartbeat",
                    method: "POST",
                    body: body
                )

                await MainActor.run {
                    AppState.shared.updateParticipants(response.members)
                }
            } catch {
                // If room no longer exists, leave it
                if case APIError.serverError(403, _) = error {
                    await MainActor.run {
                        AppState.shared.setRoom(nil)
                    }
                }
                print("Heartbeat error: \(error)")
            }
        }
    }
}
