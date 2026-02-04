import SwiftUI

struct RoomView: View {
    @ObservedObject var appState = AppState.shared
    @State private var showCopied = false

    var body: some View {
        VStack(spacing: 12) {
            // Room header
            HStack {
                VStack(alignment: .leading) {
                    Text("Room")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(appState.currentRoom?.id ?? "")
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.bold)
                }

                Spacer()

                Button(action: openStatistics) {
                    Image(systemName: "chart.bar.fill")
                }
                .buttonStyle(.borderless)
                .help("View Statistics")

                Button(action: copyRoomCode) {
                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy Room Code")
            }
            .padding(.horizontal)

            Divider()

            // Participants
            if appState.participants.isEmpty {
                Text("Loading...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(appState.participants) { participant in
                            ParticipantRow(participant: participant)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(maxHeight: 200)
            }

            Divider()

            // Leave and Quit buttons
            HStack {
                Button(action: leaveRoom) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Leave Room")
                    }
                }
                .foregroundColor(.red)
                .buttonStyle(.borderless)

                Spacer()

                Button("Quit") {
                    quitApp()
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .onAppear {
            HeartbeatService.shared.start()
        }
    }

    private func copyRoomCode() {
        if let roomId = appState.currentRoom?.id {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(roomId, forType: .string)
            showCopied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                showCopied = false
            }
        }
    }

    private func leaveRoom() {
        guard let roomId = appState.currentRoom?.id else { return }

        HeartbeatService.shared.stop()

        Task {
            try? await RoomService.shared.leaveRoom(roomId: roomId)
            await MainActor.run {
                appState.setRoom(nil)
            }
        }
    }

    private func quitApp() {
        guard let roomId = appState.currentRoom?.id else {
            NSApplication.shared.terminate(nil)
            return
        }

        HeartbeatService.shared.stop()

        Task {
            try? await RoomService.shared.leaveRoom(roomId: roomId)
            await MainActor.run {
                appState.setRoom(nil)
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func openStatistics() {
        // Post notification to open main window
        NotificationCenter.default.post(name: NSNotification.Name("OpenMainWindow"), object: nil)
    }
}

struct ParticipantRow: View {
    let participant: Participant
    @ObservedObject var appState = AppState.shared

    var isCurrentUser: Bool {
        participant.userId == appState.currentUser?.id
    }

    var body: some View {
        HStack {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(userId: participant.userId, size: 32)

                // Activity indicator
                if participant.isOnline && participant.isActive {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                }
            }

            VStack(alignment: .leading) {
                HStack {
                    Text(isCurrentUser ? "You" : "Teammate")
                        .font(.subheadline)
                    if !participant.isOnline {
                        Text("(offline)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if participant.isInFocusMode {
                        Image(systemName: "eye.slash.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                if participant.isOnline {
                    if participant.isInFocusMode {
                        Text("Focus Mode")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else if let app = participant.activeApp {
                        Text(app)
                            .font(.caption)
                            .foregroundColor(.green)
                    } else {
                        Text("Idle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .opacity(participant.isOnline ? 1.0 : 0.5)
    }
}
