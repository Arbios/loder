import Foundation

struct User: Codable, Identifiable {
    let id: String
    var deviceId: String?  // Optional now - for legacy support
    var email: String?     // Google Auth email
    var name: String?      // Google Auth display name
    var avatarPath: String?
    let isNew: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case deviceId
        case email
        case name
        case avatarPath
        case isNew
    }

    init(id: String, deviceId: String? = nil, email: String? = nil, name: String? = nil, avatarPath: String? = nil, isNew: Bool? = nil) {
        self.id = id
        self.deviceId = deviceId
        self.email = email
        self.name = name
        self.avatarPath = avatarPath
        self.isNew = isNew
    }

    init(from response: GoogleAuthResponse) {
        self.id = response.id
        self.email = response.email
        self.name = response.name
        self.avatarPath = response.avatarPath
        self.isNew = response.isNew
        self.deviceId = nil
    }
}

// Google Auth response
struct GoogleAuthResponse: Codable {
    let id: String
    let email: String
    let name: String?
    let avatarPath: String?
    let isNew: Bool
}
