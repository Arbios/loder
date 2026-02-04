import SwiftUI

struct AvatarView: View {
    let userId: String?
    let size: CGFloat
    @State private var image: NSImage?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                // Default avatar
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.secondary)
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
    }

    private func loadAvatar() {
        guard let userId = userId else {
            image = nil
            return
        }

        Task {
            let loaded = await ImageCache.shared.getImage(for: userId)
            await MainActor.run {
                self.image = loaded
                self.isLoading = false
            }
        }
    }
}
