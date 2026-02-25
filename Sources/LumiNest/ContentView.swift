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
    @AppStorage(SettingsKeys.defaultMediaRootPath) private var defaultMediaRootPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures", isDirectory: true).path

    @State private var selectedItem: MediaItem?
    @State private var isViewerMediaFullscreen = false
    @State private var isMultiSelectEnabled = false
    @State private var isSearchExpanded = false
    @State private var selectedMediaIDs: Set<URL> = []
    @State private var loadedItemLimit = 100
    @State private var clickMonitor: Any?
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

            if viewModel.isLoadingMedia {
                loadingOverlay
            }

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
            viewModel.syncDefaultRootFromSettings(loadIfNeeded: true)
            installClickMonitor()
        }
        .onDisappear {
            removeClickMonitor()
        }
        .onReceive(NotificationCenter.default.publisher(for: .luminestClearCaches)) { _ in
            thumbnailProvider.clearCache()
        }
        .onChange(of: viewModel.displayedItems.map(\.id)) { visibleIDs in
            selectedMediaIDs.formIntersection(Set(visibleIDs))
        }
        .onChange(of: viewModel.displayedItems.count) { _ in
            resetLoadedItemLimit()
        }
        .onChange(of: isSearchFocused) { focused in
            if !focused && isSearchExpanded {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSearchExpanded = false
                }
            }
        }
        .onChange(of: defaultMediaRootPath) { _ in
            viewModel.syncDefaultRootFromSettings(loadIfNeeded: true)
        }
    }

    private var layoutMode: LayoutMode {
        LayoutMode(rawValue: layoutModeRaw) ?? .grid
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Library")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)

                    if showFullPath, let folder = viewModel.selectedFolder {
                        Text(folder.path)
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.78))
                            .lineLimit(1)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    if isSearchExpanded {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Search", text: $viewModel.searchQuery)
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
                        .background(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.42), Color.blue.opacity(0.28)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSearchExpanded.toggle()
                        }
                        if isSearchExpanded {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                isSearchFocused = true
                            }
                        }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.5), Color.blue.opacity(0.32)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 17)
                                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
                            )
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }

                let count = viewModel.displayedItems.count
                Label {
                    Text("\(count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                } icon: {
                    Image(systemName: "photo.stack.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.5), Color.blue.opacity(0.32)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
            }

            HStack(spacing: 10) {
                Button {
                    viewModel.pickFolder()
                } label: {
                    Label("Select Folder", systemImage: "folder.fill.badge.plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.6), Color.blue.opacity(0.42)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        )
                        .clipShape(Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .contentShape(Capsule())
                .keyboardShortcut("o", modifiers: [.command])

                Menu {
                    if let root = viewModel.defaultRootFolder {
                        Button("Open Root: \(root.lastPathComponent)") {
                            viewModel.loadRootChildFolder(root)
                        }
                    }

                    if !viewModel.rootChildFolders.isEmpty {
                        Divider()
                        ForEach(viewModel.rootChildFolders, id: \.path) { folder in
                            Button(folder.lastPathComponent) {
                                viewModel.loadRootChildFolder(folder)
                            }
                        }
                    } else {
                        Button("No folders in root") {}
                            .disabled(true)
                    }

                    Divider()

                    Button("Change Root...") {
                        viewModel.chooseDefaultRootFolder()
                    }
                } label: {
                    Label("Folders", systemImage: "folder")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .background(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.52), Color.blue.opacity(0.30)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.40), lineWidth: 1)
                )
                .shadow(color: Color.blue.opacity(0.22), radius: 7, y: 1)

                Menu {
                    Button("All") {
                        viewModel.selectedCollectionName = nil
                        viewModel.albumScope = .all
                    }
                    Button("Favorites") {
                        viewModel.selectedCollectionName = nil
                        viewModel.albumScope = .favorites
                    }
                    if !viewModel.sortedCollectionNames.isEmpty {
                        Divider()
                        ForEach(viewModel.sortedCollectionNames, id: \.self) { name in
                            Button(name) {
                                viewModel.selectedCollectionName = name
                            }
                        }
                    }
                    Divider()
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
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "square.stack.3d.up")
                            .symbolRenderingMode(.monochrome)
                        Text("Albums")
                    }
                }
                .buttonStyle(.plain)
                .menuStyle(.borderlessButton)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.white)
                .tint(.white)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .contentShape(Capsule())
                .background(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.52), Color.blue.opacity(0.30)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.40), lineWidth: 1)
                )
                .shadow(color: Color.blue.opacity(0.22), radius: 7, y: 1)

                Menu {
                    Button("All") { viewModel.mediaFilter = .all }
                    Button("Photos") { viewModel.mediaFilter = .photos }
                    Button("Videos") { viewModel.mediaFilter = .videos }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .symbolRenderingMode(.monochrome)
                        Text(viewModel.mediaFilter.rawValue)
                    }
                }
                .buttonStyle(.plain)
                .menuStyle(.borderlessButton)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.white)
                .tint(.white)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .contentShape(Capsule())
                .background(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.52), Color.blue.opacity(0.30)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.40), lineWidth: 1)
                )
                .clipShape(Capsule())
                .shadow(color: Color.blue.opacity(0.22), radius: 7, y: 1)

                Menu {
                    ForEach(SortMode.allCases) { sort in
                        Button(sort.rawValue) {
                            viewModel.sortMode = sort
                        }
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "arrow.up.arrow.down")
                            .symbolRenderingMode(.monochrome)
                        Text(viewModel.sortMode.rawValue)
                    }
                }
                .buttonStyle(.plain)
                .menuStyle(.borderlessButton)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.white)
                .tint(.white)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .contentShape(Capsule())
                .background(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.52), Color.blue.opacity(0.30)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.40), lineWidth: 1)
                )
                .clipShape(Capsule())
                .shadow(color: Color.blue.opacity(0.22), radius: 7, y: 1)

                HStack(spacing: 0) {
                    Button {
                        layoutModeRaw = LayoutMode.grid.rawValue
                    } label: {
                        ZStack {
                            if layoutMode == .grid {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue.opacity(0.7), Color.blue.opacity(0.45)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            Image(systemName: "square.grid.3x3.fill")
                                .foregroundStyle(layoutMode == .grid ? .white : Color.white.opacity(0.78))
                        }
                        .frame(width: 44, height: 34)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        layoutModeRaw = LayoutMode.list.rawValue
                    } label: {
                        ZStack {
                            if layoutMode == .list {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue.opacity(0.7), Color.blue.opacity(0.45)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                            Image(systemName: "list.bullet")
                                .foregroundStyle(layoutMode == .list ? .white : Color.white.opacity(0.78))
                        }
                        .frame(width: 44, height: 34)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .background(Color.white.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 17)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 17))

                Spacer(minLength: 0)

                Button {
                    toggleMultiSelect()
                } label: {
                    Label(isMultiSelectEnabled ? "Selecting" : "Select", systemImage: isMultiSelectEnabled ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)

                if isMultiSelectEnabled {
                    Text("\(selectedMediaIDs.count) selected")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(Color.blue.opacity(0.35))
                        .clipShape(Capsule())
                }
            }

            Button("") {
                if !isSearchExpanded {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSearchExpanded = true
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    isSearchFocused = true
                }
            }
            .keyboardShortcut("f", modifiers: [.command])
            .frame(width: 0, height: 0)
            .opacity(0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.48), Color.gray.opacity(0.36)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.24), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func installClickMonitor() {
        guard clickMonitor == nil else { return }
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
            DispatchQueue.main.async {
                if isSearchExpanded && !isSearchFocused {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isSearchExpanded = false
                    }
                }
            }
            return event
        }
    }

    private func removeClickMonitor() {
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
            self.clickMonitor = nil
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

    private var pagedItems: [MediaItem] {
        Array(viewModel.displayedItems.prefix(loadedItemLimit))
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.22)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                Text("Loading media...")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .transition(.opacity)
    }

    private var gridView: some View {
        let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

        return ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(pagedItems) { item in
                    MediaGridCell(
                        item: item,
                        thumbnailProvider: thumbnailProvider,
                        isFavorite: showFavoriteStar && viewModel.isFavorite(item),
                        thumbnailQuality: thumbnailQuality,
                        isSelected: selectedMediaIDs.contains(item.id)
                    )
                        .onTapGesture {
                            handlePrimaryTap(on: item)
                        }
                        .onAppear {
                            loadMoreIfNeeded(currentItem: item)
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
            ForEach(pagedItems) { item in
                MediaListRow(
                    item: item,
                    thumbnailProvider: thumbnailProvider,
                    isFavorite: showFavoriteStar && viewModel.isFavorite(item),
                    thumbnailQuality: thumbnailQuality,
                    dateFormatRaw: dateFormatRaw,
                    isSelected: selectedMediaIDs.contains(item.id)
                )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        handlePrimaryTap(on: item)
                    }
                    .onAppear {
                        loadMoreIfNeeded(currentItem: item)
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

        Button(selectedMediaIDs.contains(item.id) ? "Deselect" : "Select") {
            toggleSelection(item)
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

    private func toggleMultiSelect() {
        isMultiSelectEnabled.toggle()
        if isMultiSelectEnabled {
            selectedItem = nil
        } else {
            selectedMediaIDs.removeAll()
        }
    }

    private func handlePrimaryTap(on item: MediaItem) {
        if isMultiSelectEnabled {
            toggleSelection(item)
        } else {
            selectedItem = item
        }
    }

    private func toggleSelection(_ item: MediaItem) {
        if selectedMediaIDs.contains(item.id) {
            selectedMediaIDs.remove(item.id)
        } else {
            selectedMediaIDs.insert(item.id)
        }
    }

    private func resetLoadedItemLimit() {
        loadedItemLimit = min(100, viewModel.displayedItems.count)
    }

    private func loadMoreIfNeeded(currentItem item: MediaItem) {
        guard let index = pagedItems.firstIndex(where: { $0.id == item.id }) else { return }
        let thresholdIndex = max(0, pagedItems.count - 8)
        guard index >= thresholdIndex else { return }
        guard loadedItemLimit < viewModel.displayedItems.count else { return }

        loadedItemLimit = min(loadedItemLimit + 100, viewModel.displayedItems.count)
    }

    private func generateGridImageFromSelection() {
        let selectedItems = viewModel.displayedItems.filter { selectedMediaIDs.contains($0.id) }
        let images: [(item: MediaItem, image: NSImage)] = selectedItems.compactMap { item in
            guard item.type == .image, let image = NSImage(contentsOf: item.url) else { return nil }
            return (item, image)
        }

        guard !images.isEmpty else {
            showInfoAlert(title: "No Photos Selected", message: "Select at least one photo to generate a grid image.")
            return
        }

        let count = images.count
        let columns = min(6, max(2, Int(ceil(sqrt(Double(count))))))
        let rows = Int(ceil(Double(count) / Double(columns)))
        let tileSize = CGSize(width: 420, height: 300)
        let spacing: CGFloat = 18
        let padding: CGFloat = 28
        let canvasSize = CGSize(
            width: (CGFloat(columns) * tileSize.width) + (CGFloat(columns - 1) * spacing) + (padding * 2),
            height: (CGFloat(rows) * tileSize.height) + (CGFloat(rows - 1) * spacing) + (padding * 2)
        )

        let output = NSImage(size: canvasSize)
        output.lockFocus()

        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.09, green: 0.11, blue: 0.18, alpha: 1),
            NSColor(calibratedRed: 0.13, green: 0.08, blue: 0.16, alpha: 1)
        ])
        gradient?.draw(in: NSRect(origin: .zero, size: canvasSize), angle: 30)

        for (index, entry) in images.enumerated() {
            let row = index / columns
            let column = index % columns
            let origin = CGPoint(
                x: padding + CGFloat(column) * (tileSize.width + spacing),
                y: canvasSize.height - padding - tileSize.height - CGFloat(row) * (tileSize.height + spacing)
            )
            let tileRect = NSRect(origin: origin, size: tileSize)

            let tilePath = NSBezierPath(roundedRect: tileRect, xRadius: 18, yRadius: 18)
            NSColor.white.withAlphaComponent(0.16).setStroke()
            tilePath.lineWidth = 2
            tilePath.stroke()

            NSColor.black.withAlphaComponent(0.22).setFill()
            tilePath.fill()

            NSGraphicsContext.saveGraphicsState()
            tilePath.addClip()
            drawAspectFit(image: entry.image, in: tileRect)
            NSGraphicsContext.restoreGraphicsState()
        }

        output.unlockFocus()

        guard let tiff = output.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let pngData = rep.representation(using: .png, properties: [:]) else {
            showInfoAlert(title: "Export Failed", message: "Could not generate PNG data.")
            return
        }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "LumiNest-Grid.png"
        panel.allowedFileTypes = ["png"]
        panel.title = "Export Grid Image"

        guard panel.runModal() == .OK, let destinationURL = panel.url else { return }

        do {
            try pngData.write(to: destinationURL, options: .atomic)
            NSWorkspace.shared.activateFileViewerSelecting([destinationURL])
        } catch {
            showInfoAlert(title: "Export Failed", message: "Could not write the file to disk.")
        }
    }

    private func drawAspectFit(image: NSImage, in targetRect: NSRect) {
        guard image.size.width > 0, image.size.height > 0 else { return }

        let widthRatio = targetRect.width / image.size.width
        let heightRatio = targetRect.height / image.size.height
        let scale = min(widthRatio, heightRatio)

        let scaledSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let drawRect = NSRect(
            x: targetRect.midX - (scaledSize.width / 2),
            y: targetRect.midY - (scaledSize.height / 2),
            width: scaledSize.width,
            height: scaledSize.height
        )

        image.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1)
    }

    private func showInfoAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

struct MediaGridCell: View {
    let item: MediaItem
    @ObservedObject var thumbnailProvider: ThumbnailProvider
    let isFavorite: Bool
    let thumbnailQuality: String
    let isSelected: Bool

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
                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 3 : 1)
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
    let isSelected: Bool

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
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.14) : .clear)
        )
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
        VStack(alignment: .leading, spacing: 10) {
            if isLoadingMetadata {
                HStack(spacing: 10) {
                    ProgressView()
                        .progressViewStyle(.circular)
                    Text("Loading details...")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            } else if let metadata {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(metadata.entries) { entry in
                            HStack(alignment: .top, spacing: 4) {
                                Text(entry.label)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.white.opacity(0.88))
                                    .frame(width: 96, alignment: .leading)
                                Text(entry.value)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(10)
                        }
                    }
                }
                .frame(maxHeight: 180)
            } else {
                Label("No metadata available", systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.15), Color.mint.opacity(0.08), Color.orange.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
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
