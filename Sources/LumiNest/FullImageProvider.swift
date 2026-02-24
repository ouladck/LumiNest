import AppKit
import Foundation

final class FullImageProvider {
    static let shared = FullImageProvider()

    private let cache = NSCache<NSURL, NSImage>()
    private let queue = DispatchQueue(label: "luminest.fullimage", qos: .userInitiated)

    private init() {
        applyCacheLimitFromSettings()
    }

    func load(url: URL, completion: @escaping (NSImage?) -> Void) {
        applyCacheLimitFromSettings()

        if let cached = cache.object(forKey: url as NSURL) {
            completion(cached)
            return
        }

        queue.async { [weak self] in
            let loaded = NSImage(contentsOf: url)
            if let loaded {
                self?.cache.setObject(loaded, forKey: url as NSURL)
            }

            DispatchQueue.main.async {
                completion(loaded)
            }
        }
    }

    func prefetch(url: URL) {
        applyCacheLimitFromSettings()

        if cache.object(forKey: url as NSURL) != nil {
            return
        }

        queue.async { [weak self] in
            guard let loaded = NSImage(contentsOf: url) else { return }
            self?.cache.setObject(loaded, forKey: url as NSURL)
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
