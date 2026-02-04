import Foundation

enum RoomError: LocalizedError {
    case passwordRequired
    case wrongPassword
    case roomFull

    var errorDescription: String? {
        switch self {
        case .passwordRequired: return "Password required"
        case .wrongPassword: return "Wrong password"
        case .roomFull: return "Room is full"
        }
    }
}

class RoomService {
    static let shared = RoomService()
    private let api = APIClient.shared

    private init() {}

    func createRoom(password: String? = nil) async throws -> String {
        guard let userId = AppState.shared.currentUser?.id else {
            throw APIError.invalidResponse
        }

        var body: [String: Any] = ["userId": userId]
        if let password = password, !password.isEmpty {
            body["password"] = password
        }

        let response: CreateRoomResponse = try await api.request(
            endpoint: "/rooms/create",
            method: "POST",
            body: body
        )
        return response.roomId
    }

    func checkRoom(roomId: String) async throws -> RoomCheckResponse {
        return try await api.request(endpoint: "/rooms/\(roomId)/check")
    }

    func joinRoom(roomId: String, password: String? = nil) async throws {
        guard let userId = AppState.shared.currentUser?.id else {
            throw APIError.invalidResponse
        }

        var body: [String: Any] = ["userId": userId]
        if let password = password, !password.isEmpty {
            body["password"] = password
        }

        do {
            let _: JoinRoomResponse = try await api.request(
                endpoint: "/rooms/\(roomId)/join",
                method: "POST",
                body: body
            )
        } catch APIError.serverError(401, let message) {
            if message?.contains("Password required") == true {
                throw RoomError.passwordRequired
            } else {
                throw RoomError.wrongPassword
            }
        } catch APIError.serverError(403, _) {
            throw RoomError.roomFull
        }
    }

    func leaveRoom(roomId: String) async throws {
        guard let userId = AppState.shared.currentUser?.id else {
            throw APIError.invalidResponse
        }

        let _: JoinRoomResponse = try await api.request(
            endpoint: "/rooms/\(roomId)/leave",
            method: "POST",
            body: ["userId": userId]
        )
    }

    func getRoom(roomId: String) async throws -> Room {
        return try await api.request(endpoint: "/rooms/\(roomId)")
    }

    func getStats(roomId: String, period: String = "today") async throws -> RoomStats {
        guard let userId = AppState.shared.currentUser?.id else {
            throw APIError.invalidResponse
        }

        return try await api.request(
            endpoint: "/rooms/\(roomId)/stats?userId=\(userId)&period=\(period)"
        )
    }
}

struct RoomCheckResponse: Codable {
    let exists: Bool
    let hasPassword: Bool?
}

struct CreateRoomResponse: Codable {
    let roomId: String
    let hasPassword: Bool?
}

struct JoinRoomResponse: Codable {
    let message: String
}
