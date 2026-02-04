import Foundation

struct User: Codable, Identifiable {
    let id: String
    let deviceId: String
    var avatarPath: String?
    let isNew: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case deviceId
        case avatarPath
        case isNew
    }
}
