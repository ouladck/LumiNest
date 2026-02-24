import AppKit
import Foundation

final class FullImageProvider {
    static let shared = FullImageProvider()

    private let cache = NSCache<NSURL, NSImage>()
    private let queue = DispatchQueue(label: "luminest.fullimage", qos: .userInitiated)

    private init() {
        cache.countLimit = 120
    }

    func load(url: URL, completion: @escaping (NSImage?) -> Void) {
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
        if cache.object(forKey: url as NSURL) != nil {
            return
        }

        queue.async { [weak self] in
            guard let loaded = NSImage(contentsOf: url) else { return }
            self?.cache.setObject(loaded, forKey: url as NSURL)
        }
    }
}
