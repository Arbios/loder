import Foundation
import AuthenticationServices

class GoogleAuthService: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = GoogleAuthService()

    // Google OAuth Configuration - Replace with your actual client ID
    private let clientId = "397708767571-b87cc4q5a6h6lokubas6ho8squ9ipv02.apps.googleusercontent.com"
    private let redirectUri = "com.googleusercontent.apps.397708767571-b87cc4q5a6h6lokubas6ho8squ9ipv02:/oauth2callback"
    private let scopes = "email profile"

    private var authSession: ASWebAuthenticationSession?

    private override init() {
        super.init()
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first!
    }

    func signIn() async throws -> GoogleAuthResponse {
        // Build OAuth URL
        let authUrl = buildAuthURL()

        return try await withCheckedThrowingContinuation { continuation in
            authSession = ASWebAuthenticationSession(
                url: authUrl,
                callbackURLScheme: "com.googleusercontent.apps.397708767571-b87cc4q5a6h6lokubas6ho8squ9ipv02"
            ) { [weak self] callbackURL, error in
                if let error = error {
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: GoogleAuthError.cancelled)
                    } else {
                        continuation.resume(throwing: GoogleAuthError.authFailed(error.localizedDescription))
                    }
                    return
                }

                guard let callbackURL = callbackURL,
                      let code = self?.extractCode(from: callbackURL) else {
                    continuation.resume(throwing: GoogleAuthError.noCode)
                    return
                }

                // Exchange code for user on server
                Task {
                    do {
                        let response = try await self?.exchangeCode(code)
                        if let response = response {
                            continuation.resume(returning: response)
                        } else {
                            continuation.resume(throwing: GoogleAuthError.exchangeFailed)
                        }
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            authSession?.presentationContextProvider = self
            authSession?.prefersEphemeralWebBrowserSession = false
            authSession?.start()
        }
    }

    private func buildAuthURL() -> URL {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "select_account")
        ]
        return components.url!
    }

    private func extractCode(from url: URL) -> String? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        return components?.queryItems?.first(where: { $0.name == "code" })?.value
    }

    private func exchangeCode(_ code: String) async throws -> GoogleAuthResponse {
        let api = APIClient.shared

        struct AuthRequest: Codable {
            let code: String
            let redirectUri: String
        }

        return try await api.request(
            endpoint: "/auth/google",
            method: "POST",
            body: [
                "code": code,
                "redirectUri": redirectUri
            ]
        )
    }
}

enum GoogleAuthError: Error, LocalizedError {
    case cancelled
    case authFailed(String)
    case noCode
    case exchangeFailed

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Sign in was cancelled"
        case .authFailed(let message):
            return "Authentication failed: \(message)"
        case .noCode:
            return "No authorization code received"
        case .exchangeFailed:
            return "Failed to complete sign in"
        }
    }
}
