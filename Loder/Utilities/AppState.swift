import Foundation
import SwiftUI

enum AppStatus {
    case unregistered
    case lobby
    case inRoom
}

class AppState: ObservableObject {
    static let shared = AppState()

    @Published var status: AppStatus = .unregistered
    @Published var currentUser: User?
    @Published var currentRoom: Room?
    @Published var participants: [Participant] = []
    @Published var activeApp: String? = nil  // nil = idle, String = app name
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private init() {
        loadStoredUser()
    }

    private func loadStoredUser() {
        if let userId = UserDefaults.standard.string(forKey: "com.loder.userId"),
           let deviceId = UserDefaults.standard.string(forKey: "com.loder.deviceId") {
            let avatarPath = UserDefaults.standard.string(forKey: "com.loder.avatarPath")
            self.currentUser = User(id: userId, deviceId: deviceId, avatarPath: avatarPath, isNew: false)
            self.status = .lobby

            // Check for stored room
            if let roomId = UserDefaults.standard.string(forKey: "com.loder.roomId") {
                // Will be validated by HeartbeatService on startup
                self.currentRoom = Room(id: roomId, createdBy: "", createdAt: nil, members: [])
                self.status = .inRoom
            }
        }
    }

    func setUser(_ user: User) {
        self.currentUser = user
        UserDefaults.standard.set(user.id, forKey: "com.loder.userId")
        UserDefaults.standard.set(user.deviceId, forKey: "com.loder.deviceId")
        if let avatarPath = user.avatarPath {
            UserDefaults.standard.set(avatarPath, forKey: "com.loder.avatarPath")
        }
        self.status = .lobby
    }

    func setRoom(_ room: Room?) {
        self.currentRoom = room
        if let room = room {
            UserDefaults.standard.set(room.id, forKey: "com.loder.roomId")
            self.status = .inRoom
        } else {
            UserDefaults.standard.removeObject(forKey: "com.loder.roomId")
            self.participants = []
            self.status = .lobby
        }
    }

    func updateParticipants(_ participants: [Participant]) {
        self.participants = participants
        NotificationCenter.default.post(name: NSNotification.Name("ParticipantsUpdated"), object: nil)
    }

    func updateAvatarPath(_ path: String) {
        if var user = currentUser {
            user = User(id: user.id, deviceId: user.deviceId, avatarPath: path, isNew: false)
            self.currentUser = user
            UserDefaults.standard.set(path, forKey: "com.loder.avatarPath")
        }
    }

    func logout() {
        currentUser = nil
        currentRoom = nil
        participants = []
        status = .unregistered
        UserDefaults.standard.removeObject(forKey: "com.loder.userId")
        UserDefaults.standard.removeObject(forKey: "com.loder.deviceId")
        UserDefaults.standard.removeObject(forKey: "com.loder.avatarPath")
        UserDefaults.standard.removeObject(forKey: "com.loder.roomId")
    }
}
