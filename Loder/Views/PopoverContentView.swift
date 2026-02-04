import SwiftUI

struct PopoverContentView: View {
    @ObservedObject var appState = AppState.shared
    @State private var showAvatarUpload = false

    var body: some View {
        VStack(spacing: 0) {
            if showAvatarUpload {
                AvatarUploadView(onDismiss: { showAvatarUpload = false })
            } else {
                switch appState.status {
                case .unregistered:
                    RegistrationView()
                case .lobby:
                    LobbyView(onAvatarTap: { showAvatarUpload = true })
                case .inRoom:
                    RoomView()
                }
            }
        }
        .frame(width: 280)
    }
}
