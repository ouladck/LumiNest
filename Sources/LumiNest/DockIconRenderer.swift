import AppKit
import SwiftUI

enum DockIconRenderer {
    static func makeIcon() -> NSImage? {
        let size = NSSize(width: 512, height: 512)
        let view = PrismStackLogoView(size: 512)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: size)

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            return nil
        }

        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        let image = NSImage(size: size)
        image.addRepresentation(rep)
        return image
    }
}
