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

enum AlbumScope: String, CaseIterable, Identifiable {
    case all = "All"
    case favorites = "Favorites"

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

    @Published var searchQuery: String = ""

    @Published var albumScope: AlbumScope {
        didSet {
            defaults.set(albumScope.rawValue, forKey: Self.albumScopeKey)
            if albumScope != .all {
                selectedCollectionName = nil
            }
        }
    }

    @Published var selectedCollectionName: String? {
        didSet {
            defaults.set(selectedCollectionName, forKey: Self.selectedCollectionKey)
            if selectedCollectionName != nil {
                albumScope = .all
            }
        }
    }

    @Published private(set) var favorites: Set<String> = []
    @Published private(set) var collections: [String: Set<String>] = [:]
    @Published private(set) var mediaItems: [MediaItem] = []

    var sortedCollectionNames: [String] {
        collections.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var displayedItems: [MediaItem] {
        let filteredByType: [MediaItem]

        switch mediaFilter {
        case .all:
            filteredByType = mediaItems
        case .photos:
            filteredByType = mediaItems.filter { $0.type == .image }
        case .videos:
            filteredByType = mediaItems.filter { $0.type == .video }
        }

        let filteredByAlbum: [MediaItem]

        if let selectedCollectionName,
           let collectionPaths = collections[selectedCollectionName] {
            filteredByAlbum = filteredByType.filter { collectionPaths.contains($0.url.path) }
        } else {
            switch albumScope {
            case .all:
                filteredByAlbum = filteredByType
            case .favorites:
                filteredByAlbum = filteredByType.filter { favorites.contains($0.url.path) }
            }
        }

        let searched = applySearch(to: filteredByAlbum)

        switch sortMode {
        case .name:
            return searched.sorted {
                $0.filename.localizedCaseInsensitiveCompare($1.filename) == .orderedAscending
            }
        case .date:
            return searched.sorted {
                ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
            }
        case .size:
            return searched.sorted { $0.fileSize > $1.fileSize }
        }
    }

    private let defaults = UserDefaults.standard
    private let albumStore = AlbumStore()

    private static let lastFolderPathKey = "gallery.lastFolderPath"
    private static let filterKey = "gallery.filter"
    private static let sortKey = "gallery.sort"
    private static let favoritesKey = "gallery.favorites"
    private static let collectionsKey = "gallery.collections"
    private static let albumScopeKey = "gallery.albumScope"
    private static let selectedCollectionKey = "gallery.selectedCollection"

    private let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "gif", "bmp", "tiff", "webp", "raw"
    ]

    private let videoExtensions: Set<String> = [
        "mp4", "mov", "m4v", "avi", "mkv", "wmv", "flv", "webm"
    ]

    init() {
        mediaFilter = MediaFilter(rawValue: defaults.string(forKey: Self.filterKey) ?? "") ?? .all
        sortMode = SortMode(rawValue: defaults.string(forKey: Self.sortKey) ?? "") ?? .name
        albumScope = AlbumScope(rawValue: defaults.string(forKey: Self.albumScopeKey) ?? "") ?? .all
        selectedCollectionName = defaults.string(forKey: Self.selectedCollectionKey)

        migrateLegacyDefaultsIfNeeded()
        reloadAlbumStateFromStore()

        if let selectedCollectionName,
           collections[selectedCollectionName] == nil {
            self.selectedCollectionName = nil
        }

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
            let path = item.url.path
            mediaItems.removeAll { $0.id == item.id }
            albumStore.removeMediaEverywhere(path: path)
            reloadAlbumStateFromStore()
        } catch {
            NSSound.beep()
        }
    }

    func isFavorite(_ item: MediaItem) -> Bool {
        favorites.contains(item.url.path)
    }

    func toggleFavorite(_ item: MediaItem) {
        let path = item.url.path
        let shouldFavorite = !favorites.contains(path)
        albumStore.setFavorite(path: path, isFavorite: shouldFavorite)
        reloadAlbumStateFromStore()
    }

    func createCollection(named rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        albumStore.createAlbum(name: name)
        reloadAlbumStateFromStore()
    }

    func renameCollection(from oldName: String, to newRawName: String) {
        let newName = newRawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, oldName != newName else { return }

        albumStore.renameAlbum(oldName: oldName, newName: newName)
        if selectedCollectionName == oldName {
            selectedCollectionName = newName
        }
        reloadAlbumStateFromStore()
    }

    func deleteCollection(named name: String) {
        albumStore.deleteAlbum(name: name)
        if selectedCollectionName == name {
            selectedCollectionName = nil
            albumScope = .all
        }
        reloadAlbumStateFromStore()
    }

    func add(_ item: MediaItem, toCollection name: String) {
        albumStore.addMedia(path: item.url.path, toAlbum: name)
        selectedCollectionName = name
        reloadAlbumStateFromStore()
    }

    func remove(_ item: MediaItem, fromCollection name: String) {
        albumStore.removeMedia(path: item.url.path, fromAlbum: name)
        reloadAlbumStateFromStore()
    }

    func isInCollection(_ item: MediaItem, name: String) -> Bool {
        collections[name]?.contains(item.url.path) == true
    }

    private func reloadAlbumStateFromStore() {
        favorites = albumStore.fetchFavorites()
        let names = albumStore.fetchAlbumNames()
        var map: [String: Set<String>] = [:]
        for name in names {
            map[name] = albumStore.mediaPaths(inAlbum: name)
        }
        collections = map
    }

    private func migrateLegacyDefaultsIfNeeded() {
        guard albumStore.isEmpty() else { return }

        let legacyFavorites = Set(defaults.stringArray(forKey: Self.favoritesKey) ?? [])
        if let rawCollections = defaults.dictionary(forKey: Self.collectionsKey) as? [String: [String]] {
            for (name, paths) in rawCollections {
                let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedName.isEmpty else { continue }
                albumStore.createAlbum(name: trimmedName)
                for path in paths {
                    albumStore.addMedia(path: path, toAlbum: trimmedName)
                }
            }
        }

        for path in legacyFavorites {
            albumStore.setFavorite(path: path, isFavorite: true)
        }

        defaults.removeObject(forKey: Self.favoritesKey)
        defaults.removeObject(forKey: Self.collectionsKey)
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

    private func applySearch(to items: [MediaItem]) -> [MediaItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }

        return items.filter { item in
            let filename = item.filename
            let path = item.url.path
            let ext = item.url.pathExtension

            return filename.localizedCaseInsensitiveContains(query)
                || path.localizedCaseInsensitiveContains(query)
                || ext.localizedCaseInsensitiveContains(query)
        }
    }
}
