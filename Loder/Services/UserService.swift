import Foundation

class UserService {
    static let shared = UserService()
    private let api = APIClient.shared

    private init() {}

    func register() async throws -> User {
        let deviceId = DeviceIdentifier.getDeviceId()
        return try await api.request(
            endpoint: "/users/register",
            method: "POST",
            body: ["deviceId": deviceId]
        )
    }

    func uploadAvatar(imageData: Data) async throws -> String {
        guard let userId = AppState.shared.currentUser?.id else {
            throw APIError.invalidResponse
        }
        return try await api.uploadAvatar(userId: userId, imageData: imageData)
    }
}
