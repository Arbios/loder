import Foundation

class RoomService {
    static let shared = RoomService()
    private let api = APIClient.shared

    private init() {}

    func createRoom() async throws -> String {
        guard let userId = AppState.shared.currentUser?.id else {
            throw APIError.invalidResponse
        }

        let response: CreateRoomResponse = try await api.request(
            endpoint: "/rooms/create",
            method: "POST",
            body: ["userId": userId]
        )
        return response.roomId
    }

    func joinRoom(roomId: String) async throws {
        guard let userId = AppState.shared.currentUser?.id else {
            throw APIError.invalidResponse
        }

        let _: JoinRoomResponse = try await api.request(
            endpoint: "/rooms/\(roomId)/join",
            method: "POST",
            body: ["userId": userId]
        )
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
}
