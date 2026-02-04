import SwiftUI

struct AvatarView: View {
    let userId: String?
    let avatarPath: String?
    let size: CGFloat
    @State private var image: NSImage?
    @State private var isLoading = true
    @State private var loadFailed = false

    init(userId: String?, size: CGFloat, avatarPath: String? = nil) {
        self.userId = userId
        self.size = size
        self.avatarPath = avatarPath
    }

    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else if isLoading {
                // Loading state - show subtle placeholder
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.5)
                    )
            } else {
                // Failed to load or no avatar - show rainbow noise
                RainbowNoiseAvatarView(size: size)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .onAppear {
            loadAvatar()
        }
        .onChange(of: userId) { _ in
            loadAvatar()
        }
        .onChange(of: avatarPath) { _ in
            loadAvatar()
        }
    }

    private func loadAvatar() {
        guard let userId = userId else {
            image = nil
            isLoading = false
            return
        }

        isLoading = true
        loadFailed = false

        Task {
            let loaded = await ImageCache.shared.getImage(for: userId, avatarPath: avatarPath)
            await MainActor.run {
                self.image = loaded
                self.isLoading = false
                self.loadFailed = (loaded == nil)
            }
        }
    }
}

// MARK: - Rainbow Noise Avatar (reusable component)
struct RainbowNoiseAvatarView: View {
    let size: CGFloat
    @State private var phase: Double = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, canvasSize in
                let step: CGFloat = max(4, size / 12)
                for x in stride(from: 0, to: canvasSize.width, by: step) {
                    for y in stride(from: 0, to: canvasSize.height, by: step) {
                        let noise = sin(x * 0.15 + time * 2) * cos(y * 0.15 + time * 2.5)
                        let hue = (noise + 1) / 2
                        let color = Color(hue: hue, saturation: 0.7, brightness: 0.6)
                        let rect = CGRect(x: x, y: y, width: step, height: step)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
