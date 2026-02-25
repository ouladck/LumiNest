import AppKit
import Darwin
import Foundation

enum MediaFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case photos = "Photos"
    case videos = "Videos"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .all: return L10n.s("common.all")
        case .photos: return L10n.s("media.photos")
        case .videos: return L10n.s("media.videos")
        }
    }
}

enum SortMode: String, CaseIterable, Identifiable {
    case name = "Name"
    case date = "Date"
    case size = "Size"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .name: return L10n.s("sort.name")
        case .date: return L10n.s("sort.date")
        case .size: return L10n.s("sort.size")
        }
    }
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
                stopMonitoringFolder()
                return
            }
            defaults.set(selectedFolder.path, forKey: Self.lastFolderPathKey)
        }
    }

    @Published var mediaFilter: MediaFilter {
        didSet {
            defaults.set(mediaFilter.rawValue, forKey: Self.filterKey)
            refreshDisplayedItems()
        }
    }

    @Published var sortMode: SortMode {
        didSet {
            defaults.set(sortMode.rawValue, forKey: Self.sortKey)
            refreshDisplayedItems()
        }
    }

    @Published var searchQuery: String = "" {
        didSet {
            refreshDisplayedItems(debounced: true)
        }
    }

    @Published var albumScope: AlbumScope {
        didSet {
            defaults.set(albumScope.rawValue, forKey: Self.albumScopeKey)
            if albumScope != .all {
                selectedCollectionName = nil
            }
            refreshDisplayedItems()
        }
    }

    @Published var selectedCollectionName: String? {
        didSet {
            defaults.set(selectedCollectionName, forKey: Self.selectedCollectionKey)
            if selectedCollectionName != nil {
                albumScope = .all
            }
            refreshDisplayedItems()
        }
    }

    @Published private(set) var favorites: Set<String> = []
    @Published private(set) var collections: [String: Set<String>] = [:]
    @Published private(set) var mediaItems: [MediaItem] = []
    @Published private(set) var displayedItems: [MediaItem] = []
    @Published private(set) var isLoadingMedia = false
    @Published private(set) var defaultRootFolder: URL?
    @Published private(set) var rootChildFolders: [URL] = []

    var sortedCollectionNames: [String] {
        collections.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
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
    private var folderMonitorSource: DispatchSourceFileSystemObject?
    private var folderMonitorDescriptor: CInt = -1
    private var pendingMonitorReload: DispatchWorkItem?
    private var pendingSearchRefresh: DispatchWorkItem?
    private var displayedItemsRefreshGeneration: Int = 0

    deinit {
        pendingSearchRefresh?.cancel()
        stopMonitoringFolder()
    }

    init() {
        mediaFilter = MediaFilter(rawValue: defaults.string(forKey: Self.filterKey) ?? "") ?? .all
        let fallbackSort = defaults.string(forKey: SettingsKeys.defaultSort) ?? SortMode.name.rawValue
        sortMode = SortMode(rawValue: defaults.string(forKey: Self.sortKey) ?? fallbackSort) ?? .name
        albumScope = AlbumScope(rawValue: defaults.string(forKey: Self.albumScopeKey) ?? "") ?? .all
        selectedCollectionName = defaults.string(forKey: Self.selectedCollectionKey)

        migrateLegacyDefaultsIfNeeded()
        reloadAlbumStateFromStore()

        let fallbackRoot = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures", isDirectory: true)
        let configuredRootPath = defaults.string(forKey: SettingsKeys.defaultMediaRootPath) ?? fallbackRoot.path
        if defaults.string(forKey: SettingsKeys.defaultMediaRootPath) == nil {
            defaults.set(configuredRootPath, forKey: SettingsKeys.defaultMediaRootPath)
        }
        let configuredRootURL = URL(fileURLWithPath: configuredRootPath)
        setDefaultRootFolder(configuredRootURL, persist: false)

        if let selectedCollectionName,
           collections[selectedCollectionName] == nil {
            self.selectedCollectionName = nil
        }

        let shouldOpenLastFolder = defaults.object(forKey: SettingsKeys.openLastFolderOnLaunch) as? Bool ?? true
        if shouldOpenLastFolder, let savedPath = defaults.string(forKey: Self.lastFolderPathKey) {
            let savedURL = URL(fileURLWithPath: savedPath)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: savedPath, isDirectory: &isDirectory), isDirectory.boolValue {
                selectedFolder = savedURL
                loadMedia(from: savedURL)
            }
        } else if let defaultRootFolder {
            loadMedia(from: defaultRootFolder)
        }

        refreshDisplayedItems()
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

    func chooseDefaultRootFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Default Root"
        panel.message = "Pick a default root path that contains your photo/video folders."
        panel.directoryURL = defaultRootFolder

        if panel.runModal() == .OK, let folder = panel.url {
            setDefaultRootFolder(folder, persist: true)
            loadMedia(from: folder)
        }
    }

    func loadRootChildFolder(_ folder: URL) {
        loadMedia(from: folder)
    }

    func syncDefaultRootFromSettings(loadIfNeeded: Bool = false) {
        let fallbackRoot = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures", isDirectory: true)
        let configuredRootPath = defaults.string(forKey: SettingsKeys.defaultMediaRootPath) ?? fallbackRoot.path
        let configuredRootURL = URL(fileURLWithPath: configuredRootPath)
        setDefaultRootFolder(configuredRootURL, persist: false)

        if loadIfNeeded, selectedFolder == nil {
            loadMedia(from: configuredRootURL)
        }
    }

    func loadMedia(from folder: URL, restartMonitor: Bool = true) {
        selectedFolder = folder
        if restartMonitor {
            startMonitoringFolder(folder)
        }
        DispatchQueue.main.async {
            self.isLoadingMedia = true
        }

        let priorityRaw = defaults.string(forKey: SettingsKeys.scanPriority) ?? ScanPriorityOption.fast.rawValue
        let priority = ScanPriorityOption(rawValue: priorityRaw) ?? .fast

        DispatchQueue.global(qos: priority.qos).async {
            let items = self.scanFolder(folder)
            DispatchQueue.main.async {
                self.mediaItems = items
                self.refreshDisplayedItems()
                self.isLoadingMedia = false
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
            refreshDisplayedItems()
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
        let autoSelect = defaults.object(forKey: SettingsKeys.autoSelectCreatedAlbum) as? Bool ?? true
        if autoSelect {
            selectedCollectionName = name
        }
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
        refreshDisplayedItems()
    }

    private func setDefaultRootFolder(_ url: URL, persist: Bool) {
        defaultRootFolder = url
        if persist {
            defaults.set(url.path, forKey: SettingsKeys.defaultMediaRootPath)
        }
        rootChildFolders = discoverImmediateDirectories(in: url)
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

    private func discoverImmediateDirectories(in root: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isHiddenKey, .nameKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls.compactMap { url in
            let values = try? url.resourceValues(forKeys: Set(keys))
            guard values?.isDirectory == true else { return nil }
            return url
        }
        .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    private func refreshDisplayedItems(debounced: Bool = false) {
        if debounced {
            pendingSearchRefresh?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.refreshDisplayedItems(debounced: false)
            }
            pendingSearchRefresh = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
            return
        }

        displayedItemsRefreshGeneration += 1
        let generation = displayedItemsRefreshGeneration

        let snapshotMediaItems = mediaItems
        let snapshotFilter = mediaFilter
        let snapshotSort = sortMode
        let snapshotSearchQuery = searchQuery
        let snapshotAlbumScope = albumScope
        let snapshotSelectedCollectionName = selectedCollectionName
        let snapshotCollections = collections
        let snapshotFavorites = favorites

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let filteredByType: [MediaItem]

            switch snapshotFilter {
            case .all:
                filteredByType = snapshotMediaItems
            case .photos:
                filteredByType = snapshotMediaItems.filter { $0.type == .image }
            case .videos:
                filteredByType = snapshotMediaItems.filter { $0.type == .video }
            }

            let filteredByAlbum: [MediaItem]

            if let snapshotSelectedCollectionName,
               let collectionPaths = snapshotCollections[snapshotSelectedCollectionName] {
                filteredByAlbum = filteredByType.filter { collectionPaths.contains($0.url.path) }
            } else {
                switch snapshotAlbumScope {
                case .all:
                    filteredByAlbum = filteredByType
                case .favorites:
                    filteredByAlbum = filteredByType.filter { snapshotFavorites.contains($0.url.path) }
                }
            }

            let query = snapshotSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            let searched: [MediaItem]
            if query.isEmpty {
                searched = filteredByAlbum
            } else {
                searched = filteredByAlbum.filter { item in
                    let filename = item.filename
                    let path = item.url.path
                    let ext = item.url.pathExtension

                    return filename.localizedCaseInsensitiveContains(query)
                        || path.localizedCaseInsensitiveContains(query)
                        || ext.localizedCaseInsensitiveContains(query)
                }
            }

            let sorted: [MediaItem]
            switch snapshotSort {
            case .name:
                sorted = searched.sorted {
                    $0.filename.localizedCaseInsensitiveCompare($1.filename) == .orderedAscending
                }
            case .date:
                sorted = searched.sorted {
                    ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
                }
            case .size:
                sorted = searched.sorted { $0.fileSize > $1.fileSize }
            }

            DispatchQueue.main.async {
                guard generation == self.displayedItemsRefreshGeneration else { return }
                self.displayedItems = sorted
            }
        }
    }

    private func startMonitoringFolder(_ folder: URL) {
        stopMonitoringFolder()

        let descriptor = open(folder.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        folderMonitorDescriptor = descriptor
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .rename, .attrib, .extend],
            queue: DispatchQueue.global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            self?.scheduleReloadFromFolderMonitor()
        }

        source.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.folderMonitorDescriptor >= 0 {
                close(self.folderMonitorDescriptor)
                self.folderMonitorDescriptor = -1
            }
        }

        folderMonitorSource = source
        source.resume()
    }

    private func stopMonitoringFolder() {
        pendingMonitorReload?.cancel()
        pendingMonitorReload = nil
        folderMonitorSource?.cancel()
        folderMonitorSource = nil
    }

    private func scheduleReloadFromFolderMonitor() {
        pendingMonitorReload?.cancel()

        let work = DispatchWorkItem { [weak self] in
            guard let self, let folder = self.selectedFolder else { return }
            self.loadMedia(from: folder, restartMonitor: false)
        }
        pendingMonitorReload = work

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }
}
