import Foundation

struct Room: Codable, Identifiable {
    let id: String
    let createdBy: String
    let createdAt: String?
    var members: [Participant]

    enum CodingKeys: String, CodingKey {
        case id = "roomId"
        case createdBy
        case createdAt
        case members
    }
}
