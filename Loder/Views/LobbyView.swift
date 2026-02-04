import SwiftUI

struct LobbyView: View {
    @ObservedObject var appState = AppState.shared
    @State private var roomCode = UserDefaults.standard.string(forKey: "com.loder.lastRoomCode") ?? ""
    @State private var isJoining = false
    @State private var isCreating = false
    @State private var errorMessage: String?

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

            // Create room
            Button(action: createRoom) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text(isCreating ? "Creating..." : "Create New Room")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isCreating || isJoining)
            .padding(.horizontal)

            // Join room
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
                        }

                    Button(action: joinRoom) {
                        Text(isJoining ? "..." : "Join")
                    }
                    .buttonStyle(.bordered)
                    .disabled(roomCode.count < 7 || isJoining || isCreating)
                }
                .padding(.horizontal)
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

        Task {
            do {
                let roomId = try await RoomService.shared.createRoom()
                let room = try await RoomService.shared.getRoom(roomId: roomId)
                await MainActor.run {
                    appState.setRoom(room)
                    HeartbeatService.shared.start()
                    isCreating = false
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

    private func joinRoom() {
        isJoining = true
        errorMessage = nil

        Task {
            do {
                try await RoomService.shared.joinRoom(roomId: roomCode)
                let room = try await RoomService.shared.getRoom(roomId: roomCode)
                await MainActor.run {
                    appState.setRoom(room)
                    HeartbeatService.shared.start()
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
}
