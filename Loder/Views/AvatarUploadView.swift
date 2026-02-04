import SwiftUI
import UniformTypeIdentifiers

struct AvatarUploadView: View {
    @ObservedObject var appState = AppState.shared
    @State private var selectedImage: NSImage?
    @State private var isUploading = false
    @State private var errorMessage: String?

    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Header with back button
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .buttonStyle(.borderless)
                Spacer()
            }
            .padding(.horizontal)

            Text("Set Your Avatar")
                .font(.headline)

            // Preview
            if let image = selectedImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
            } else {
                AvatarView(userId: appState.currentUser?.id, size: 100)
            }

            // Select button
            Button("Choose Image") {
                selectImage()
            }
            .buttonStyle(.bordered)

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Button(action: uploadAvatar) {
                if isUploading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("Save")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedImage == nil || isUploading)

            Spacer()
        }
        .padding()
    }

    private func selectImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .gif]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        panel.begin { response in
            if response == .OK, let url = panel.url {
                DispatchQueue.main.async {
                    self.selectedImage = NSImage(contentsOf: url)
                }
            }
        }
    }

    private func uploadAvatar() {
        guard let image = selectedImage,
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            errorMessage = "Failed to process image"
            return
        }

        isUploading = true
        errorMessage = nil

        Task {
            do {
                let avatarPath = try await UserService.shared.uploadAvatar(imageData: pngData)
                await MainActor.run {
                    appState.updateAvatarPath(avatarPath)
                    if let userId = appState.currentUser?.id {
                        ImageCache.shared.clearCache(for: userId)
                    }
                    onDismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Upload failed"
                    isUploading = false
                }
            }
        }
    }
}
