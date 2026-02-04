import SwiftUI
import UniformTypeIdentifiers

struct SettingsWindow: View {
    @ObservedObject var appState = AppState.shared
    @State private var selectedImage: NSImage?
    @State private var isUploading = false
    @State private var isDeleting = false
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "1a1a2e"), Color(hex: "16213e"), Color(hex: "0f3460")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom title bar
                SettingsTitleBar(onClose: {
                    SettingsWindowController.shared.close()
                })

                ScrollView {
                    VStack(spacing: 24) {
                        // Avatar Section
                        VStack(spacing: 16) {
                            Text("Profile")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack(spacing: 20) {
                                // Avatar preview
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(colors: [.cyan, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        )
                                        .frame(width: 90, height: 90)
                                        .blur(radius: 15)
                                        .opacity(0.5)

                                    if let image = selectedImage {
                                        Image(nsImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(Circle())
                                    } else {
                                        AvatarView(userId: appState.currentUser?.id, size: 80)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Your Avatar")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.white)

                                    HStack(spacing: 12) {
                                        Button(action: selectImage) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "photo")
                                                Text("Choose")
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                        }
                                        .buttonStyle(.bordered)

                                        if selectedImage != nil {
                                            Button(action: uploadAvatar) {
                                                if isUploading {
                                                    ProgressView()
                                                        .scaleEffect(0.7)
                                                } else {
                                                    HStack(spacing: 6) {
                                                        Image(systemName: "arrow.up.circle")
                                                        Text("Save")
                                                    }
                                                }
                                            }
                                            .buttonStyle(.borderedProminent)
                                            .disabled(isUploading)
                                        }
                                    }
                                }

                                Spacer()
                            }
                        }
                        .padding(20)
                        .glassCard(glowColor: .cyan)

                        // Focus Mode Section
                        VStack(spacing: 16) {
                            Text("Privacy")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Focus Mode")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.white)
                                    Text("Hide your activity status from others")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                }

                                Spacer()

                                Toggle("", isOn: Binding(
                                    get: { appState.focusMode },
                                    set: { newValue in
                                        appState.setFocusMode(newValue)
                                    }
                                ))
                                .toggleStyle(.switch)
                                .tint(.cyan)
                            }

                            if appState.focusMode {
                                HStack(spacing: 8) {
                                    Image(systemName: "eye.slash.fill")
                                        .foregroundColor(.orange)
                                    Text("Your activity is hidden from teammates")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(20)
                        .glassCard(glowColor: .purple)

                        // Account Section
                        VStack(spacing: 16) {
                            Text("Account")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            // Logout
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Logout")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.white)
                                    Text("Sign out from this device")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                }

                                Spacer()

                                Button(action: logout) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                        Text("Logout")
                                    }
                                    .foregroundColor(.orange)
                                }
                                .buttonStyle(.bordered)
                            }

                            Divider()
                                .background(Color.white.opacity(0.2))

                            // Delete Account
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Delete Account")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.white)
                                    Text("Remove your account and anonymize data")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                }

                                Spacer()

                                Button(action: { showDeleteConfirmation = true }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "trash")
                                        Text("Delete")
                                    }
                                    .foregroundColor(.red)
                                }
                                .buttonStyle(.bordered)
                                .disabled(isDeleting)
                            }
                        }
                        .padding(20)
                        .glassCard(glowColor: .red.opacity(0.5))

                        // Messages
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        }

                        if let success = successMessage {
                            Text(success)
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.horizontal)
                        }

                        // App Info
                        VStack(spacing: 8) {
                            Text("Loder v1.3.0")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.4))
                            Text("Made with love")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .padding(.top, 8)
                    }
                    .padding(24)
                }
            }
        }
        .frame(minWidth: 450, minHeight: 500)
        .alert("Delete Account", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("This will remove your account and anonymize your activity data. This action cannot be undone.")
        }
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
        successMessage = nil

        Task {
            do {
                let avatarPath = try await UserService.shared.uploadAvatar(imageData: pngData)
                await MainActor.run {
                    appState.updateAvatarPath(avatarPath)
                    if let userId = appState.currentUser?.id {
                        ImageCache.shared.clearCache(for: userId)
                    }
                    selectedImage = nil
                    isUploading = false
                    successMessage = "Avatar updated successfully!"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        successMessage = nil
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Upload failed: \(error.localizedDescription)"
                    isUploading = false
                }
            }
        }
    }

    private func logout() {
        HeartbeatService.shared.stop()
        SettingsWindowController.shared.close()
        StatisticsWindowController.shared.close()
        appState.logout()
    }

    private func deleteAccount() {
        guard let userId = appState.currentUser?.id else { return }

        isDeleting = true
        errorMessage = nil

        Task {
            do {
                try await UserService.shared.deleteAccount(userId: userId)
                await MainActor.run {
                    HeartbeatService.shared.stop()
                    SettingsWindowController.shared.close()
                    StatisticsWindowController.shared.close()
                    appState.logout()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to delete account: \(error.localizedDescription)"
                    isDeleting = false
                }
            }
        }
    }
}

// MARK: - Settings Title Bar

struct SettingsTitleBar: View {
    var onClose: () -> Void

    var body: some View {
        HStack {
            // Close button (red)
            Button(action: onClose) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.black.opacity(0.5))
                    )
            }
            .buttonStyle(.plain)
            .help("Close")

            Spacer()

            Text("Settings")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.8))

            Spacer()

            // Placeholder for symmetry
            Circle()
                .fill(Color.clear)
                .frame(width: 12, height: 12)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.3))
        .background(WindowDragArea())
    }
}

// MARK: - Settings Window Controller

class SettingsWindowController: NSObject {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func showSettings() {
        if let existingWindow = window {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = SettingsWindow()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 580),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = "Settings"
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.setFrameAutosaveName("SettingsWindow")
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.hasShadow = true
        window.minSize = NSSize(width: 400, height: 450)

        // Round corners
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 12
        window.contentView?.layer?.masksToBounds = true

        // Show in dock
        NSApp.setActivationPolicy(.regular)

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.close()
    }
}

extension SettingsWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        window = nil

        // Hide from dock if no other windows visible
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let visibleWindows = NSApp.windows.filter { $0.isVisible && !($0 is NSPanel) }
            if visibleWindows.isEmpty {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}
