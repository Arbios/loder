import Foundation

struct RoomStats: Codable {
    let roomId: String
    let period: String
    let members: [MemberStats]
    let topApps: [AppStats]
    let generatedAt: String
}

struct MemberStats: Codable, Identifiable {
    let userId: String
    let avatarPath: String?
    let totalSeconds: Int
    let apps: [AppStats]
    let hourlyActivity: [String: Int]

    var id: String { userId }

    var totalHours: Double {
        Double(totalSeconds) / 3600.0
    }

    var formattedTime: String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct AppStats: Codable, Identifiable {
    let appName: String
    let totalSeconds: Int

    var id: String { appName }

    var formattedTime: String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "<1m"
        }
    }

    var percentage: Double {
        // Will be calculated relative to total
        0
    }
}
