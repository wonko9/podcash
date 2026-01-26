import SwiftUI
import Foundation

/// Simple image cache with memory and disk storage
actor ImageCache {
    static let shared = ImageCache()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private var cacheDirectory: URL?

    private init() {
        memoryCache.countLimit = 100
        setupCacheDirectory()
    }

    private func setupCacheDirectory() {
        if let cachePath = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let imageCache = cachePath.appendingPathComponent("ImageCache", isDirectory: true)
            if !fileManager.fileExists(atPath: imageCache.path) {
                try? fileManager.createDirectory(at: imageCache, withIntermediateDirectories: true)
            }
            cacheDirectory = imageCache
        }
    }

    func image(for url: URL) async -> UIImage? {
        let key = cacheKey(for: url)

        // Check memory cache
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }

        // Check disk cache
        if let diskImage = loadFromDisk(key: key) {
            memoryCache.setObject(diskImage, forKey: key as NSString)
            return diskImage
        }

        // Download
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else {
            return nil
        }

        // Store in caches
        memoryCache.setObject(image, forKey: key as NSString)
        saveToDisk(image: image, key: key)

        return image
    }

    private func cacheKey(for url: URL) -> String {
        // Create a safe filename from URL using SHA256 hash
        let urlString = url.absoluteString
        guard let data = urlString.data(using: .utf8) else {
            return UUID().uuidString + ".jpg"
        }

        // Simple hash using built-in hashValue and additional mixing
        var hash: UInt64 = 5381
        for byte in data {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }
        return String(format: "%016llx", hash) + ".jpg"
    }

    private func loadFromDisk(key: String) -> UIImage? {
        guard let cacheDir = cacheDirectory else { return nil }
        let fileURL = cacheDir.appendingPathComponent(key)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    private func saveToDisk(image: UIImage, key: String) {
        guard let cacheDir = cacheDirectory,
              let data = image.jpegData(compressionQuality: 0.8) else { return }
        let fileURL = cacheDir.appendingPathComponent(key)
        try? data.write(to: fileURL)
    }

    func clearCache() {
        memoryCache.removeAllObjects()
        if let cacheDir = cacheDirectory {
            try? fileManager.removeItem(at: cacheDir)
            setupCacheDirectory()
        }
    }
}

// MARK: - Cached Async Image View

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .task(id: url) {
                        await loadImage()
                    }
            }
        }
    }

    private func loadImage() async {
        guard let url = url, !isLoading else { return }
        isLoading = true

        if let cachedImage = await ImageCache.shared.image(for: url) {
            await MainActor.run {
                self.image = cachedImage
            }
        }

        isLoading = false
    }
}

// Convenience initializer matching AsyncImage API
extension CachedAsyncImage where Placeholder == Color {
    init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content) {
        self.url = url
        self.content = content
        self.placeholder = { Color.secondary.opacity(0.2) }
    }
}
