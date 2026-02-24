import AppKit
import QuickLookThumbnailing

@MainActor
final class ThumbnailProvider: ObservableObject {
    private var cache: [URL: NSImage] = [:]

    func thumbnail(for url: URL, size: CGFloat, completion: @escaping (NSImage?) -> Void) {
        if let cached = cache[url] {
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
                    self?.cache[url] = image
                    completion(image)
                } else {
                    completion(nil)
                }
            }
        }
    }
}
