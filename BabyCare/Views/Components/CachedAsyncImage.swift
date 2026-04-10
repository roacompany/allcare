import SwiftUI
import UIKit

// MARK: - ImageCacheManager

@MainActor
final class ImageCacheManager {
    static let shared = ImageCacheManager()

    private let memoryCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 50
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        return cache
    }()

    private var diskCacheDirectory: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = caches.appendingPathComponent("ImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cacheKey(for urlString: String) -> NSString {
        return NSString(string: urlString)
    }

    private func diskURL(for urlString: String) -> URL {
        let hash = abs(urlString.hashValue)
        return diskCacheDirectory.appendingPathComponent("\(hash).cache")
    }

    func image(for urlString: String) async -> UIImage? {
        let key = cacheKey(for: urlString)

        // 1. Memory cache
        if let cached = memoryCache.object(forKey: key) {
            return cached
        }

        // 2. Disk cache
        let diskFileURL = diskURL(for: urlString)
        if let data = try? Data(contentsOf: diskFileURL),
           let img = UIImage(data: data) {
            memoryCache.setObject(img, forKey: key, cost: data.count)
            return img
        }

        // 3. Network download
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let img = UIImage(data: data) else { return nil }
            store(img, data: data, for: urlString)
            return img
        } catch {
            return nil
        }
    }

    func store(_ image: UIImage, for urlString: String) {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        store(image, data: data, for: urlString)
    }

    private func store(_ image: UIImage, data: Data, for urlString: String) {
        let key = cacheKey(for: urlString)
        memoryCache.setObject(image, forKey: key, cost: data.count)
        let diskFileURL = diskURL(for: urlString)
        try? data.write(to: diskFileURL)
    }
}

// MARK: - CachedAsyncImage

struct CachedAsyncImage<Placeholder: View>: View {
    let url: String?
    let size: CGSize
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else if isLoading {
                ProgressView()
                    .frame(width: size.width, height: size.height)
            } else {
                placeholder()
                    .frame(width: size.width, height: size.height)
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    @MainActor
    private func loadImage() async {
        guard let urlString = url, !urlString.isEmpty else { return }
        isLoading = true
        image = await ImageCacheManager.shared.image(for: urlString)
        isLoading = false
    }
}
