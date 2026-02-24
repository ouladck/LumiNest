import AppKit
import QuickLookThumbnailing

@MainActor
final class ThumbnailProvider: ObservableObject {
    private let cache = NSCache<NSURL, NSImage>()

    init() {
        applyCacheLimitFromSettings()
    }

    func thumbnail(for url: URL, size: CGFloat, completion: @escaping (NSImage?) -> Void) {
        applyCacheLimitFromSettings()

        if let cached = cache.object(forKey: url as NSURL) {
            completion(cached)
            return
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: size, height: size),
            scale: NSScreen.main?.backingScaleFactor ?? 2,
            representationTypes: .thumbnail
        )

        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
            DispatchQueue.main.async {
                if let cgImage = representation?.cgImage {
                    let image = NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
                    self?.cache.setObject(image, forKey: url as NSURL)
                    completion(image)
                } else {
                    completion(nil)
                }
            }
        }
    }

    func clearCache() {
        cache.removeAllObjects()
    }

    private func applyCacheLimitFromSettings() {
        let raw = UserDefaults.standard.string(forKey: SettingsKeys.thumbnailCacheLimit) ?? ThumbnailCacheLimitOption.medium.rawValue
        let option = ThumbnailCacheLimitOption(rawValue: raw) ?? .medium
        cache.countLimit = option.countLimit
    }
}
