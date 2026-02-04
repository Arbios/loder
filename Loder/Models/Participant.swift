import Foundation

struct Participant: Codable, Identifiable {
    let userId: String
    var avatarPath: String?
    var activeApp: String?  // nil = idle, String = app name
    var isOnline: Bool

    var id: String { userId }

    var isActive: Bool { activeApp != nil }

    enum CodingKeys: String, CodingKey {
        case userId
        case avatarPath
        case activeApp
        case isOnline
    }
}

struct HeartbeatResponse: Codable {
    let members: [Participant]
}
