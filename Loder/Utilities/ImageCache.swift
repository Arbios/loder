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

    func getImage(for userId: String) async -> NSImage? {
        // Check memory cache
        if let cached = cache.object(forKey: userId as NSString) {
            return cached
        }

        // Check disk cache
        let fileURL = cacheDirectory.appendingPathComponent("\(userId).png")
        if let data = try? Data(contentsOf: fileURL),
           let image = NSImage(data: data) {
            cache.setObject(image, forKey: userId as NSString)
            return image
        }

        // Fetch from server
        guard let url = APIClient.shared.getAvatarURL(userId: userId) else {
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let image = NSImage(data: data) else {
                return nil
            }

            // Save to caches
            cache.setObject(image, forKey: userId as NSString)
            try? data.write(to: fileURL)

            return image
        } catch {
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
