import AVKit
import AppKit
import SwiftUI

enum LayoutMode: String, CaseIterable, Identifiable {
    case grid = "Grid"
    case list = "List"

    var id: String { rawValue }
}

struct ContentView: View {
    @StateObject private var viewModel = GalleryViewModel()
    @StateObject private var thumbnailProvider = ThumbnailProvider()

    @AppStorage("gallery.layout") private var layoutModeRaw = LayoutMode.grid.rawValue
    @AppStorage(SettingsKeys.defaultLayout) private var defaultLayoutRaw = LayoutMode.grid.rawValue
    @AppStorage(SettingsKeys.showFullPath) private var showFullPath = true
    @AppStorage(SettingsKeys.copyPathFormat) private var copyPathFormat = CopyPathFormatOption.absolute.rawValue
    @AppStorage(SettingsKeys.confirmMoveToTrash) private var confirmMoveToTrash = true
    @AppStorage(SettingsKeys.confirmFavoriteRemoval) private var confirmFavoriteRemoval = false
    @AppStorage(SettingsKeys.confirmAlbumDelete) private var confirmAlbumDelete = true
    @AppStorage(SettingsKeys.showFavoriteStar) private var showFavoriteStar = true
    @AppStorage(SettingsKeys.thumbnailQuality) private var thumbnailQuality = ThumbnailQualityOption.medium.rawValue
    @AppStorage(SettingsKeys.dateFormat) private var dateFormatRaw = DateFormatOption.system.rawValue

    @State private var selectedItem: MediaItem?
    @State private var isViewerMediaFullscreen = false
    @FocusState private var isSearchFocused: Bool
    @State private var didApplyDefaultLayout = false

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                header

                if viewModel.displayedItems.isEmpty {
                    emptyState
                } else if layoutMode == .grid {
                    gridView
                } else {
                    listView
                }
            }
            .padding(16)

            if let media = selectedItem {
                ZStack {
                    Color.black.opacity(0.48)
                        .ignoresSafeArea()
                        .onTapGesture {
                            selectedItem = nil
                        }

                    MediaViewer(
                        mediaItems: viewModel.displayedItems,
                        initialItem: media,
                        isFavorite: { viewModel.isFavorite($0) },
                        onToggleFavorite: { toggleFavoriteWithOptionalConfirm($0) },
                        isExternalFullscreen: $isViewerMediaFullscreen,
                        onClose: { selectedItem = nil }
                    )
                    .frame(
                        maxWidth: isViewerMediaFullscreen ? .infinity : 1100,
                        maxHeight: isViewerMediaFullscreen ? .infinity : 760
                    )
                    .onTapGesture {
                        // Prevent tap-through to backdrop close gesture.
                    }
                }
                .transition(.opacity)
                .onDisappear {
                    isViewerMediaFullscreen = false
                }
            }
        }
        .onAppear {
            applyDefaultLayoutIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .luminestClearCaches)) { _ in
            thumbnailProvider.clearCache()
        }
    }

    private var layoutMode: LayoutMode {
        LayoutMode(rawValue: layoutModeRaw) ?? .grid
    }

    private var header: some View {
        HStack {
            Button {
                viewModel.pickFolder()
            } label: {
                Label("Select Folder", systemImage: "folder.fill.badge.plus")
                    .font(.headline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut("o", modifiers: [.command])

            if showFullPath, let folder = viewModel.selectedFolder {
                Text(folder.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 20)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search media", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .frame(width: 220)

                if !viewModel.searchQuery.isEmpty {
                    Button {
                        viewModel.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 9))

            Picker("Album", selection: Binding(
                get: { viewModel.selectedCollectionName ?? viewModel.albumScope.rawValue },
                set: { newValue in
                    if let collection = viewModel.sortedCollectionNames.first(where: { $0 == newValue }) {
                        viewModel.selectedCollectionName = collection
                    } else {
                        viewModel.selectedCollectionName = nil
                        viewModel.albumScope = AlbumScope(rawValue: newValue) ?? .all
                    }
                }
            )) {
                Text("All").tag(AlbumScope.all.rawValue)
                Text("Favorites").tag(AlbumScope.favorites.rawValue)
                ForEach(viewModel.sortedCollectionNames, id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .frame(width: 160)

            Menu {
                Button("New Album...") {
                    promptForNewAlbum(prefilledItem: nil)
                }

                if let selected = viewModel.selectedCollectionName {
                    Button("Rename \"\(selected)\"...") {
                        promptRenameSelectedAlbum()
                    }
                    Button("Delete \"\(selected)\"") {
                        confirmDeleteSelectedAlbum()
                    }
                }

                if !viewModel.sortedCollectionNames.isEmpty {
                    Divider()
                    Menu("Delete Album") {
                        ForEach(viewModel.sortedCollectionNames, id: \.self) { name in
                            Button(name) {
                                confirmDeleteAlbum(named: name)
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "folder.badge.gearshape")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)

            Picker("Filter", selection: $viewModel.mediaFilter) {
                ForEach(MediaFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .frame(width: 140)

            Picker("Sort", selection: $viewModel.sortMode) {
                ForEach(SortMode.allCases) { sort in
                    Text(sort.rawValue).tag(sort)
                }
            }
            .frame(width: 130)

            Picker("View", selection: Binding(
                get: { LayoutMode(rawValue: layoutModeRaw) ?? .grid },
                set: { layoutModeRaw = $0.rawValue }
            )) {
                ForEach(LayoutMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)

            Text("\(viewModel.displayedItems.count)")
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)

            Button("") {
                isSearchFocused = true
            }
            .keyboardShortcut("f", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text(viewModel.mediaItems.isEmpty ? "No media found" : "No matching results")
                .font(.title3)
            Text(viewModel.mediaItems.isEmpty
                 ? "Choose a folder that contains photos or videos."
                 : "Try a different search term.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var gridView: some View {
        let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

        return ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(viewModel.displayedItems) { item in
                    MediaGridCell(
                        item: item,
                        thumbnailProvider: thumbnailProvider,
                        isFavorite: showFavoriteStar && viewModel.isFavorite(item),
                        thumbnailQuality: thumbnailQuality
                    )
                        .onTapGesture {
                            selectedItem = item
                        }
                        .contextMenu {
                            mediaContextMenu(for: item)
                        }
                }
            }
            .padding(.top, 4)
        }
    }

    private var listView: some View {
        List {
            ForEach(viewModel.displayedItems) { item in
                MediaListRow(
                    item: item,
                    thumbnailProvider: thumbnailProvider,
                    isFavorite: showFavoriteStar && viewModel.isFavorite(item),
                    thumbnailQuality: thumbnailQuality,
                    dateFormatRaw: dateFormatRaw
                )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedItem = item
                    }
                    .contextMenu {
                        mediaContextMenu(for: item)
                    }
            }
        }
        .listStyle(.inset)
    }

    @ViewBuilder
    private func mediaContextMenu(for item: MediaItem) -> some View {
        Button(viewModel.isFavorite(item) ? "Remove Favorite" : "Add to Favorites") {
            toggleFavoriteWithOptionalConfirm(item)
        }

        Menu("Add to Album") {
            Button("New Album...") {
                promptForNewAlbum(prefilledItem: item)
            }

            if viewModel.sortedCollectionNames.isEmpty {
                Button("No albums yet") {}
                    .disabled(true)
            } else {
                Divider()
                ForEach(viewModel.sortedCollectionNames, id: \.self) { name in
                    Button(viewModel.isInCollection(item, name: name) ? "Added: \(name)" : name) {
                        viewModel.add(item, toCollection: name)
                    }
                    .disabled(viewModel.isInCollection(item, name: name))
                }
            }
        }

        if let selectedCollection = viewModel.selectedCollectionName,
           viewModel.isInCollection(item, name: selectedCollection) {
            Button("Remove from \"\(selectedCollection)\"") {
                viewModel.remove(item, fromCollection: selectedCollection)
            }
        }

        Divider()

        Button("Open") {
            selectedItem = item
        }

        Button("Reveal in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([item.url])
        }

        Button("Copy Path") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(copiedPath(for: item), forType: .string)
        }

        Divider()

        Button("Move to Trash") {
            if confirmMoveToTrash {
                let alert = NSAlert()
                alert.messageText = "Move to Trash"
                alert.informativeText = "Move this media to Trash?"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Move")
                alert.addButton(withTitle: "Cancel")
                guard alert.runModal() == .alertFirstButtonReturn else { return }
            }

            if selectedItem?.id == item.id {
                selectedItem = nil
            }
            viewModel.delete(item)
        }
    }

    private func promptForNewAlbum(prefilledItem: MediaItem?) {
        let alert = NSAlert()
        alert.messageText = "New Album"
        alert.informativeText = "Enter a name for your album."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.placeholderString = "Album name"
        alert.accessoryView = input

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let name = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        viewModel.createCollection(named: name)
        if let prefilledItem {
            viewModel.add(prefilledItem, toCollection: name)
        } else {
            viewModel.selectedCollectionName = name
        }
    }

    private func promptRenameSelectedAlbum() {
        guard let selected = viewModel.selectedCollectionName else { return }

        let alert = NSAlert()
        alert.messageText = "Rename Album"
        alert.informativeText = "Choose a new name for this album."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.stringValue = selected
        alert.accessoryView = input

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        viewModel.renameCollection(from: selected, to: input.stringValue)
    }

    private func confirmDeleteSelectedAlbum() {
        guard let selected = viewModel.selectedCollectionName else { return }
        confirmDeleteAlbum(named: selected)
    }

    private func confirmDeleteAlbum(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if !confirmAlbumDelete {
            viewModel.deleteCollection(named: trimmed)
            return
        }

        let alert = NSAlert()
        alert.messageText = "Delete Album"
        alert.informativeText = "Delete \"\(trimmed)\"? Media files will not be deleted."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        viewModel.deleteCollection(named: trimmed)
    }

    private func copiedPath(for item: MediaItem) -> String {
        let format = CopyPathFormatOption(rawValue: copyPathFormat) ?? .absolute
        guard format == .relative, let folder = viewModel.selectedFolder else {
            return item.url.path
        }

        let base = folder.standardizedFileURL.path
        let full = item.url.standardizedFileURL.path
        guard full.hasPrefix(base + "/") else { return full }
        return String(full.dropFirst(base.count + 1))
    }

    private func applyDefaultLayoutIfNeeded() {
        guard !didApplyDefaultLayout else { return }
        didApplyDefaultLayout = true

        if UserDefaults.standard.object(forKey: "gallery.layout") == nil {
            layoutModeRaw = defaultLayoutRaw
        }
    }

    private func toggleFavoriteWithOptionalConfirm(_ item: MediaItem) {
        if viewModel.isFavorite(item) && confirmFavoriteRemoval {
            let alert = NSAlert()
            alert.messageText = "Remove Favorite"
            alert.informativeText = "Remove this media from favorites?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Remove")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        viewModel.toggleFavorite(item)
    }
}

struct MediaGridCell: View {
    let item: MediaItem
    @ObservedObject var thumbnailProvider: ThumbnailProvider
    let isFavorite: Bool
    let thumbnailQuality: String

    @State private var thumbnail: NSImage?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(Color.gray.opacity(0.12))

            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                ProgressView()
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.5)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack {
                Spacer()

                HStack {
                    Text(item.type == .video ? "VIDEO" : "PHOTO")
                        .font(.caption2.bold())
                        .padding(5)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    Spacer()

                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption.bold())
                            .padding(6)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                            .foregroundStyle(.yellow)
                    }
                }
            }
            .padding(6)
        }
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            let quality = ThumbnailQualityOption(rawValue: thumbnailQuality) ?? .medium
            thumbnailProvider.thumbnail(for: item.url, size: quality.pixelSize) { image in
                thumbnail = image
            }
        }
    }
}

struct MediaListRow: View {
    let item: MediaItem
    @ObservedObject var thumbnailProvider: ThumbnailProvider
    let isFavorite: Bool
    let thumbnailQuality: String
    let dateFormatRaw: String

    @State private var thumbnail: NSImage?

    private var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: item.fileSize, countStyle: .file)
    }

    private var formattedDate: String {
        guard let createdAt = item.createdAt else { return "Unknown date" }
        let option = DateFormatOption(rawValue: dateFormatRaw) ?? .system
        let formatter = DateFormatter()
        switch option {
        case .system:
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
        case .us:
            formatter.dateFormat = "MM/dd/yyyy"
        case .eu:
            formatter.dateFormat = "dd/MM/yyyy"
        case .iso:
            formatter.dateFormat = "yyyy-MM-dd"
        }
        return formatter.string(from: createdAt)
    }

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    ProgressView()
                }
            }
            .frame(width: 70, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.filename)
                        .lineLimit(1)
                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }
                Text("\(item.type == .video ? "Video" : "Photo") • \(formattedDate) • \(formattedSize)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .onAppear {
            let quality = ThumbnailQualityOption(rawValue: thumbnailQuality) ?? .medium
            thumbnailProvider.thumbnail(for: item.url, size: max(120, quality.pixelSize * 0.65)) { image in
                thumbnail = image
            }
        }
    }
}

struct MediaViewer: View {
    let mediaItems: [MediaItem]
    let initialItem: MediaItem
    let isFavorite: (MediaItem) -> Bool
    let onToggleFavorite: (MediaItem) -> Void
    @Binding var isExternalFullscreen: Bool
    let onClose: () -> Void

    @AppStorage(SettingsKeys.viewerAutoplay) private var viewerAutoplay = true
    @AppStorage(SettingsKeys.viewerLoopVideo) private var viewerLoopVideo = false
    @AppStorage(SettingsKeys.viewerSwipeSensitivity) private var swipeSensitivity: Double = 40
    @AppStorage(SettingsKeys.preloadNeighbors) private var preloadNeighbors = true

    @State private var currentIndex: Int = 0
    @State private var player: AVPlayer?
    @State private var image: NSImage?
    @State private var isLoadingImage = false
    @State private var metadata: MediaMetadata?
    @State private var isLoadingMetadata = false
    @State private var isDetailsExpanded = false
    @State private var isMediaOnlyFullscreen = false
    @State private var keyMonitor: Any?
    @State private var playerEndObserver: NSObjectProtocol?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(currentItem.filename)
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
                    .lineLimit(1)

                Spacer()

                Button {
                    toggleCurrentFavorite()
                } label: {
                    Image(systemName: isFavorite(currentItem) ? "star.fill" : "star")
                }
                .buttonStyle(.plain)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isFavorite(currentItem) ? .yellow : .primary)
                .frame(width: 34, height: 34)
                .background(.thinMaterial)
                .clipShape(Circle())

                Button {
                    isDetailsExpanded.toggle()
                } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.plain)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isDetailsExpanded ? .primary : .secondary)
                .frame(width: 34, height: 34)
                .background(.thinMaterial)
                .clipShape(Circle())

                Button {
                    isMediaOnlyFullscreen.toggle()
                    isExternalFullscreen = isMediaOnlyFullscreen
                } label: {
                    Image(systemName: isMediaOnlyFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.plain)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(.thinMaterial)
                .clipShape(Circle())

                Text("Number \(currentIndex + 1) / \(mediaItems.count)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(height: 34)
                    .padding(.horizontal, 12)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
            }

            if isMediaOnlyFullscreen {
                ZStack {
                    mediaCanvas(cornerRadius: 0)
                        .ignoresSafeArea()

                    HStack {
                        sideArrow(systemName: "chevron.left", disabled: currentIndex == 0) {
                            previous()
                        }
                        Spacer()
                        sideArrow(systemName: "chevron.right", disabled: currentIndex == mediaItems.count - 1) {
                            next()
                        }
                    }
                    .padding(.horizontal, 18)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack(spacing: 14) {
                    sideArrow(systemName: "chevron.left", disabled: currentIndex == 0) {
                        previous()
                    }

                    mediaCanvas(cornerRadius: 12)

                    sideArrow(systemName: "chevron.right", disabled: currentIndex == mediaItems.count - 1) {
                        next()
                    }
                }

                if isDetailsExpanded {
                    metadataPanel
                }
            }
        }
        .padding(isMediaOnlyFullscreen ? 0 : 18)
        .background {
            if !isMediaOnlyFullscreen {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: isMediaOnlyFullscreen ? 0 : 16))
        .shadow(radius: isMediaOnlyFullscreen ? 0 : 18)
        .onAppear {
            if let index = mediaItems.firstIndex(of: initialItem) {
                currentIndex = index
            }
            isDetailsExpanded = false
            prepareCurrentItem()
            installKeyMonitor()
        }
        .onDisappear {
            player?.pause()
            removeKeyMonitor()
            removePlayerEndObserver()
            isExternalFullscreen = false
        }
        .onChange(of: currentIndex) { _ in
            prepareCurrentItem()
        }
        .onExitCommand {
            onClose()
        }
        .onMoveCommand { direction in
            switch direction {
            case .left:
                previous()
            case .right:
                next()
            default:
                break
            }
        }
    }

    @ViewBuilder
    private func sideArrow(systemName: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title2.weight(.semibold))
                .frame(width: 42, height: 42)
                .background(.thinMaterial)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .opacity(disabled ? 0.25 : 1)
        .disabled(disabled)
    }

    private var currentItem: MediaItem {
        mediaItems[currentIndex]
    }

    private func previous() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
    }

    private func next() {
        guard currentIndex < mediaItems.count - 1 else { return }
        currentIndex += 1
    }

    private func prepareCurrentItem() {
        loadMetadata(for: currentItem)

        if currentItem.type == .video {
            image = nil
            isLoadingImage = false
            player = AVPlayer(url: currentItem.url)
            configurePlayerEndObserver()
            if viewerAutoplay {
                player?.play()
            }
        } else {
            player?.pause()
            player = nil
            removePlayerEndObserver()
            isLoadingImage = true
            let requestedURL = currentItem.url

            FullImageProvider.shared.load(url: currentItem.url) { loaded in
                guard currentItem.url == requestedURL else { return }
                image = loaded
                isLoadingImage = false
            }
        }

        prefetchNeighbors()
    }

    @ViewBuilder
    private var metadataPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLoadingMetadata {
                ProgressView()
                    .progressViewStyle(.circular)
            } else if let metadata {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(metadata.entries) { entry in
                            HStack(alignment: .top, spacing: 8) {
                                Text(entry.label)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 88, alignment: .leading)
                                Text(entry.value)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .frame(maxHeight: 150)
            } else {
                Text("No metadata available")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func loadMetadata(for item: MediaItem) {
        let requestedPath = item.url.path
        isLoadingMetadata = true
        metadata = nil

        DispatchQueue.global(qos: .userInitiated).async {
            let extracted = MediaMetadataExtractor.extract(for: item)
            DispatchQueue.main.async {
                guard currentItem.url.path == requestedPath else { return }
                metadata = extracted
                isLoadingMetadata = false
            }
        }
    }

    private func prefetchNeighbors() {
        guard preloadNeighbors else { return }

        let neighbors = [currentIndex - 1, currentIndex + 1]
            .filter { mediaItems.indices.contains($0) }
            .map { mediaItems[$0] }

        for item in neighbors where item.type == .image {
            FullImageProvider.shared.prefetch(url: item.url)
        }
    }

    @ViewBuilder
    private func mediaCanvas(cornerRadius: CGFloat) -> some View {
        Group {
            if currentItem.type == .image {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                } else if isLoadingImage {
                    ProgressView()
                } else {
                    Text("Could not open image")
                        .foregroundStyle(.secondary)
                }
            } else {
                if let player {
                    VideoPlayer(player: player)
                } else {
                    ProgressView()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .gesture(
            DragGesture(minimumDistance: 25)
                .onEnded { value in
                    let threshold = -abs(swipeSensitivity)
                    if value.translation.width < threshold {
                        next()
                    } else if value.translation.width > abs(swipeSensitivity) {
                        previous()
                    }
                }
        )
    }

    private func togglePlayback() {
        guard let player else { return }
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    private func toggleCurrentFavorite() {
        onToggleFavorite(currentItem)
    }

    private func replayCurrentVideo() {
        guard currentItem.type == .video, let player else { return }
        player.seek(to: .zero)
        player.play()
    }

    private func configurePlayerEndObserver() {
        removePlayerEndObserver()
        guard viewerLoopVideo, let item = player?.currentItem else { return }

        playerEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            player?.seek(to: .zero)
            player?.play()
        }
    }

    private func removePlayerEndObserver() {
        if let playerEndObserver {
            NotificationCenter.default.removeObserver(playerEndObserver)
            self.playerEndObserver = nil
        }
    }

    private func installKeyMonitor() {
        removeKeyMonitor()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 49: // Space
                togglePlayback()
                return nil
            case 3: // F
                toggleCurrentFavorite()
                return nil
            case 15: // R
                replayCurrentVideo()
                return nil
            case 53: // Escape
                onClose()
                return nil
            case 123: // Left arrow
                previous()
                return nil
            case 124: // Right arrow
                next()
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }
}
