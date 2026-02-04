import Foundation
import AppKit

class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSString, NSImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    private init() {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("com.loder.avatars")
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func getImage(for userId: String, avatarPath: String? = nil) async -> NSImage? {
        // Use a stable cache key based on the URL or userId
        let cacheKey = (avatarPath ?? userId) as NSString

        // Check memory cache
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        // Check disk cache (use hash of URL for filename to handle external URLs)
        let fileKey = avatarPath?.data(using: .utf8)?.base64EncodedString() ?? userId
        let safeFileKey = fileKey.replacingOccurrences(of: "/", with: "_").prefix(50)
        let fileURL = cacheDirectory.appendingPathComponent("\(safeFileKey).png")

        if let data = try? Data(contentsOf: fileURL),
           let image = NSImage(data: data) {
            cache.setObject(image, forKey: cacheKey)
            return image
        }

        // Determine URL to fetch from
        let url: URL?
        if let avatarPath = avatarPath, avatarPath.hasPrefix("http") {
            // External URL (e.g., Google profile picture)
            url = URL(string: avatarPath)
        } else if avatarPath != nil {
            // Has a path but not HTTP - skip (local path or invalid)
            return nil
        } else {
            // No avatar path - try fetching from our API server
            url = APIClient.shared.getAvatarURL(userId: userId)
        }

        guard let fetchURL = url else {
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: fetchURL)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let image = NSImage(data: data) else {
                print("ImageCache: Failed to load image from \(fetchURL), status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return nil
            }

            // Save to caches
            cache.setObject(image, forKey: cacheKey)
            try? data.write(to: fileURL)

            return image
        } catch {
            print("ImageCache: Error loading image from \(fetchURL): \(error)")
            return nil
        }
    }

    func clearCache(for userId: String) {
        cache.removeObject(forKey: userId as NSString)
        let fileURL = cacheDirectory.appendingPathComponent("\(userId).png")
        try? fileManager.removeItem(at: fileURL)
    }

    func clearAll() {
        cache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
}
