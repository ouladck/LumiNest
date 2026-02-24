import AppKit
import Foundation

enum MediaFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case photos = "Photos"
    case videos = "Videos"

    var id: String { rawValue }
}

enum SortMode: String, CaseIterable, Identifiable {
    case name = "Name"
    case date = "Date"
    case size = "Size"

    var id: String { rawValue }
}

final class GalleryViewModel: ObservableObject {
    @Published var selectedFolder: URL? {
        didSet {
            guard let selectedFolder else {
                defaults.removeObject(forKey: Self.lastFolderPathKey)
                return
            }
            defaults.set(selectedFolder.path, forKey: Self.lastFolderPathKey)
        }
    }

    @Published var mediaFilter: MediaFilter {
        didSet {
            defaults.set(mediaFilter.rawValue, forKey: Self.filterKey)
        }
    }

    @Published var sortMode: SortMode {
        didSet {
            defaults.set(sortMode.rawValue, forKey: Self.sortKey)
        }
    }

    @Published private(set) var mediaItems: [MediaItem] = []

    var displayedItems: [MediaItem] {
        let filtered: [MediaItem]

        switch mediaFilter {
        case .all:
            filtered = mediaItems
        case .photos:
            filtered = mediaItems.filter { $0.type == .image }
        case .videos:
            filtered = mediaItems.filter { $0.type == .video }
        }

        switch sortMode {
        case .name:
            return filtered.sorted {
                $0.filename.localizedCaseInsensitiveCompare($1.filename) == .orderedAscending
            }
        case .date:
            return filtered.sorted {
                ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
            }
        case .size:
            return filtered.sorted { $0.fileSize > $1.fileSize }
        }
    }

    private let defaults = UserDefaults.standard

    private static let lastFolderPathKey = "gallery.lastFolderPath"
    private static let filterKey = "gallery.filter"
    private static let sortKey = "gallery.sort"

    private let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "gif", "bmp", "tiff", "webp", "raw"
    ]

    private let videoExtensions: Set<String> = [
        "mp4", "mov", "m4v", "avi", "mkv", "wmv", "flv", "webm"
    ]

    init() {
        mediaFilter = MediaFilter(rawValue: defaults.string(forKey: Self.filterKey) ?? "") ?? .all
        sortMode = SortMode(rawValue: defaults.string(forKey: Self.sortKey) ?? "") ?? .name

        if let savedPath = defaults.string(forKey: Self.lastFolderPathKey) {
            let savedURL = URL(fileURLWithPath: savedPath)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: savedPath, isDirectory: &isDirectory), isDirectory.boolValue {
                selectedFolder = savedURL
                loadMedia(from: savedURL)
            }
        }
    }

    func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Folder"

        if panel.runModal() == .OK, let folder = panel.url {
            loadMedia(from: folder)
        }
    }

    func loadMedia(from folder: URL) {
        selectedFolder = folder

        DispatchQueue.global(qos: .userInitiated).async {
            let items = self.scanFolder(folder)
            DispatchQueue.main.async {
                self.mediaItems = items
            }
        }
    }

    func delete(_ item: MediaItem) {
        do {
            var trashed: NSURL?
            try FileManager.default.trashItem(at: item.url, resultingItemURL: &trashed)
            mediaItems.removeAll { $0.id == item.id }
        } catch {
            NSSound.beep()
        }
    }

    private func scanFolder(_ folder: URL) -> [MediaItem] {
        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .creationDateKey,
            .contentModificationDateKey,
            .fileSizeKey
        ]

        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var items: [MediaItem] = []

        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            let type: MediaType

            if imageExtensions.contains(ext) {
                type = .image
            } else if videoExtensions.contains(ext) {
                type = .video
            } else {
                continue
            }

            let values = try? fileURL.resourceValues(forKeys: Set(keys))
            let createdAt = values?.creationDate ?? values?.contentModificationDate
            let fileSize = Int64(values?.fileSize ?? 0)

            items.append(
                MediaItem(
                    url: fileURL,
                    type: type,
                    createdAt: createdAt,
                    fileSize: fileSize
                )
            )
        }

        return items
    }
}
