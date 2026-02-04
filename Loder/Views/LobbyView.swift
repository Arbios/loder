import SwiftUI

struct LobbyView: View {
    @ObservedObject var appState = AppState.shared
    @State private var roomCode = UserDefaults.standard.string(forKey: "com.loder.lastRoomCode") ?? ""
    @State private var roomPassword = ""
    @State private var createPassword = ""
    @State private var isJoining = false
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var showPasswordField = false
    @State private var showCreatePasswordField = false
    @State private var needsPassword = false

    var onAvatarTap: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Header with avatar
            HStack {
                AvatarView(userId: appState.currentUser?.id, size: 40)
                    .onTapGesture { onAvatarTap() }

                VStack(alignment: .leading) {
                    Text("Ready to collaborate")
                        .font(.headline)
                    Text("Create or join a room")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal)

            Divider()

            // Create room section
            VStack(spacing: 8) {
                // Password toggle for creation
                HStack {
                    Toggle(isOn: $showCreatePasswordField) {
                        HStack(spacing: 4) {
                            Image(systemName: showCreatePasswordField ? "lock.fill" : "lock.open")
                                .font(.caption)
                            Text("Password protect")
                                .font(.caption)
                        }
                    }
                    .toggleStyle(.checkbox)
                    .foregroundColor(.secondary)

                    Spacer()
                }
                .padding(.horizontal)

                if showCreatePasswordField {
                    SecureField("Room password", text: $createPassword)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                }

                Button(action: createRoom) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(isCreating ? "Creating..." : "Create New Room")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCreating || isJoining || (showCreatePasswordField && createPassword.isEmpty))
                .padding(.horizontal)
            }

            // Join room section
            VStack(spacing: 8) {
                Text("or join existing")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    TextField("Room code", text: $roomCode)
                        .textFieldStyle(.roundedBorder)
                        .textCase(.uppercase)
                        .onChange(of: roomCode) { newValue in
                            roomCode = String(newValue.uppercased().prefix(7))
                            UserDefaults.standard.set(roomCode, forKey: "com.loder.lastRoomCode")
                            needsPassword = false
                            showPasswordField = false
                        }

                    Button(action: checkAndJoinRoom) {
                        Text(isJoining ? "..." : "Join")
                    }
                    .buttonStyle(.bordered)
                    .disabled(roomCode.count < 7 || isJoining || isCreating)
                }
                .padding(.horizontal)

                // Password field (shows when needed)
                if showPasswordField {
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        SecureField("Enter room password", text: $roomPassword)
                            .textFieldStyle(.roundedBorder)
                        Button("Join") {
                            joinWithPassword()
                        }
                        .buttonStyle(.bordered)
                        .disabled(roomPassword.isEmpty || isJoining)
                    }
                    .padding(.horizontal)
                }
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            Divider()

            // Footer
            HStack {
                Button("Logout") {
                    appState.logout()
                }
                .font(.caption)
                .foregroundColor(.secondary)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }

    private func createRoom() {
        isCreating = true
        errorMessage = nil

        let password = showCreatePasswordField ? createPassword : nil

        Task {
            do {
                let roomId = try await RoomService.shared.createRoom(password: password)
                let room = try await RoomService.shared.getRoom(roomId: roomId)
                await MainActor.run {
                    appState.setRoom(room)
                    HeartbeatService.shared.start()
                    isCreating = false
                    createPassword = ""
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create room: \(error.localizedDescription)"
                    print("Create room error: \(error)")
                    isCreating = false
                }
            }
        }
    }

    private func checkAndJoinRoom() {
        isJoining = true
        errorMessage = nil

        Task {
            do {
                // First check if room requires password
                let check = try await RoomService.shared.checkRoom(roomId: roomCode)
                if check.hasPassword == true {
                    await MainActor.run {
                        needsPassword = true
                        showPasswordField = true
                        isJoining = false
                    }
                    return
                }

                // No password needed, join directly
                try await RoomService.shared.joinRoom(roomId: roomCode)
                let room = try await RoomService.shared.getRoom(roomId: roomCode)
                await MainActor.run {
                    appState.setRoom(room)
                    HeartbeatService.shared.start()
                    isJoining = false
                }
            } catch RoomError.passwordRequired {
                await MainActor.run {
                    needsPassword = true
                    showPasswordField = true
                    isJoining = false
                }
            } catch RoomError.roomFull {
                await MainActor.run {
                    errorMessage = "Room is full (max 10 members)"
                    isJoining = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Room not found"
                    isJoining = false
                }
            }
        }
    }

    private func joinWithPassword() {
        isJoining = true
        errorMessage = nil

        Task {
            do {
                try await RoomService.shared.joinRoom(roomId: roomCode, password: roomPassword)
                let room = try await RoomService.shared.getRoom(roomId: roomCode)
                await MainActor.run {
                    appState.setRoom(room)
                    HeartbeatService.shared.start()
                    isJoining = false
                    roomPassword = ""
                    showPasswordField = false
                }
            } catch RoomError.wrongPassword {
                await MainActor.run {
                    errorMessage = "Wrong password"
                    isJoining = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to join room"
                    isJoining = false
                }
            }
        }
    }
}
