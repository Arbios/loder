import SwiftUI

struct RegistrationView: View {
    @ObservedObject var appState = AppState.shared
    @State private var isRegistering = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.fill")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("Welcome to Loder")
                .font(.headline)

            Text("Connect with your team and see Claude activity in real-time.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Button(action: register) {
                if isRegistering {
                    ProgressView()
                        .scaleEffect(0.8)
                        .frame(width: 100)
                } else {
                    Text("Get Started")
                        .frame(width: 100)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRegistering)
        }
        .padding()
        .onAppear {
            // Auto-register on appear
            register()
        }
    }

    private func register() {
        guard !isRegistering else { return }
        isRegistering = true
        errorMessage = nil

        Task {
            do {
                let user = try await UserService.shared.register()
                await MainActor.run {
                    appState.setUser(user)
                    isRegistering = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Registration failed. Tap to retry."
                    isRegistering = false
                }
            }
        }
    }
}
