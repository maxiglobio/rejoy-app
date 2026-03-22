import SwiftUI
import UIKit

/// In-memory and disk cache for avatar images. Persists between app launches for instant display.
enum AvatarImageCache {
    private static let cache = NSCache<NSString, UIImage>()
    private static let maxCount = 50

    /// Shared URLSession with URLCache for HTTP caching. Used by prefetch and CachedAvatarImage.
    static let sharedAvatarURLSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 10 * 1024 * 1024, diskCapacity: 50 * 1024 * 1024)
        config.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: config)
    }()

    private static var diskCacheDir: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("AvatarCache", isDirectory: true)
    }

    static func image(for url: URL) -> UIImage? {
        if let mem = cache.object(forKey: url.absoluteString as NSString) { return mem }
        return loadFromDisk(url: url)
    }

    static func set(_ image: UIImage, for url: URL) {
        let cost = image.jpegData(compressionQuality: 0.8)?.count ?? 50_000
        cache.setObject(image, forKey: url.absoluteString as NSString, cost: cost)
        saveToDisk(image: image, url: url)
    }

    static func configure() {
        cache.countLimit = maxCount
        cache.totalCostLimit = 10 * 1024 * 1024  // 10 MB
        _ = ensureDiskCacheDir()
    }

    private static func ensureDiskCacheDir() -> URL? {
        guard let dir = diskCacheDir else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func diskPath(for url: URL) -> URL? {
        guard let dir = diskCacheDir else { return nil }
        let key = url.absoluteString
        var hasher = Hasher()
        hasher.combine(key)
        let hash = abs(hasher.finalize())
        return dir.appendingPathComponent("\(hash).jpg")
    }

    private static func loadFromDisk(url: URL) -> UIImage? {
        guard let path = diskPath(for: url),
              FileManager.default.fileExists(atPath: path.path),
              let data = try? Data(contentsOf: path),
              let img = UIImage(data: data) else { return nil }
        cache.setObject(img, forKey: url.absoluteString as NSString, cost: data.count)
        return img
    }

    private static func saveToDisk(image: UIImage, url: URL) {
        guard let path = diskPath(for: url),
              ensureDiskCacheDir() != nil,
              let data = image.jpegData(compressionQuality: 0.8) else { return }
        try? data.write(to: path)
    }

    /// Returns thumbnail URL for Supabase Storage images (requires Supabase Pro). Returns nil for non-Supabase URLs.
    static func thumbnailURL(for url: URL, width: Int = 200, height: Int = 200) -> URL? {
        let s = url.absoluteString
        guard s.contains("/storage/v1/object/public/") else { return nil }
        let transformed = s.replacingOccurrences(of: "/storage/v1/object/public/", with: "/storage/v1/render/image/public/")
        var components = URLComponents(string: transformed)
        components?.queryItems = [URLQueryItem(name: "width", value: "\(width)"), URLQueryItem(name: "height", value: "\(height)")]
        return components?.url
    }

    private static let maxConcurrentPrefetch = 4

    /// Prefetch avatar URLs in background. Call when member profiles are loaded.
    static func prefetch(urls: [URL]) {
        Task.detached(priority: .utility) {
            let toFetch = urls.filter { image(for: $0) == nil }
            for chunk in stride(from: 0, to: toFetch.count, by: maxConcurrentPrefetch) {
                let batch = Array(toFetch[chunk..<min(chunk + maxConcurrentPrefetch, toFetch.count)])
                await withTaskGroup(of: Void.self) { group in
                    for url in batch {
                        group.addTask {
                            let urlsToTry: [URL] = {
                                if let thumb = thumbnailURL(for: url) { return [thumb, url] }
                                return [url]
                            }()
                            for tryURL in urlsToTry {
                                if let (data, _) = try? await sharedAvatarURLSession.data(from: tryURL),
                                   let img = UIImage(data: data) {
                                    set(img, for: url)
                                    break
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
