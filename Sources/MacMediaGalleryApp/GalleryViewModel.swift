import AppKit
import Foundation

final class GalleryViewModel: ObservableObject {
    @Published var selectedFolder: URL?
    @Published var mediaItems: [MediaItem] = []

    private let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "gif", "bmp", "tiff", "webp", "raw"
    ]

    private let videoExtensions: Set<String> = [
        "mp4", "mov", "m4v", "avi", "mkv", "wmv", "flv", "webm"
    ]

    func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Folder"

        if panel.runModal() == .OK, let folder = panel.url {
            selectedFolder = folder
            loadMedia(from: folder)
        }
    }

    func loadMedia(from folder: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            let items = self.scanFolder(folder)
            DispatchQueue.main.async {
                self.mediaItems = items
            }
        }
    }

    private func scanFolder(_ folder: URL) -> [MediaItem] {
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var items: [MediaItem] = []

        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            if imageExtensions.contains(ext) {
                items.append(MediaItem(url: fileURL, type: .image))
            } else if videoExtensions.contains(ext) {
                items.append(MediaItem(url: fileURL, type: .video))
            }
        }

        return items.sorted { $0.url.lastPathComponent.localizedCaseInsensitiveCompare($1.url.lastPathComponent) == .orderedAscending }
    }
}
