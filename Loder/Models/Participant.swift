import Foundation

struct Participant: Codable, Identifiable {
    let userId: String
    var avatarPath: String?
    var activeApp: String?  // nil = idle, String = app name
    var isOnline: Bool
    var focusMode: Bool?  // User is in focus mode (hidden status)

    var id: String { userId }

    var isActive: Bool { activeApp != nil && focusMode != true }

    var isInFocusMode: Bool { focusMode == true }

    enum CodingKeys: String, CodingKey {
        case userId
        case avatarPath
        case activeApp
        case isOnline
        case focusMode
    }
}

struct HeartbeatResponse: Codable {
    let members: [Participant]
}
