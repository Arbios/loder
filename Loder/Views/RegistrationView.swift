import SwiftUI

struct RegistrationView: View {
    @ObservedObject var appState = AppState.shared
    @State private var isSigningIn = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Logo
            Image(systemName: "person.3.fill")
                .font(.system(size: 50))
                .foregroundColor(.accentColor)

            Text("Welcome to Loder")
                .font(.title2)
                .fontWeight(.semibold)

            Text("See what your team is working on in real-time")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Google Sign-In Button
            Button(action: signInWithGoogle) {
                HStack(spacing: 12) {
                    if isSigningIn {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "g.circle.fill")
                            .font(.title2)
                        Text("Sign in with Google")
                            .fontWeight(.medium)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSigningIn)
            .padding(.horizontal, 24)

            Spacer()
                .frame(height: 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func signInWithGoogle() {
        guard !isSigningIn else { return }
        isSigningIn = true
        errorMessage = nil

        Task {
            do {
                let response = try await GoogleAuthService.shared.signIn()
                let user = User(from: response)
                await MainActor.run {
                    appState.setUser(user)
                    isSigningIn = false
                }
            } catch GoogleAuthError.cancelled {
                await MainActor.run {
                    isSigningIn = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSigningIn = false
                }
            }
        }
    }
}
