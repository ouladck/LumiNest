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
    @State private var selectedItem: MediaItem?

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
                        onClose: { selectedItem = nil }
                    )
                    .frame(maxWidth: 1100, maxHeight: 760)
                    .onTapGesture {
                        // Prevent tap-through to backdrop close gesture.
                    }
                }
                .transition(.opacity)
            }
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

            if let folder = viewModel.selectedFolder {
                Text(folder.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 20)

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
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No media found")
                .font(.title3)
            Text("Choose a folder that contains photos or videos.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var gridView: some View {
        let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

        return ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(viewModel.displayedItems) { item in
                    MediaGridCell(item: item, thumbnailProvider: thumbnailProvider)
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
                MediaListRow(item: item, thumbnailProvider: thumbnailProvider)
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
        Button("Open") {
            selectedItem = item
        }

        Button("Reveal in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([item.url])
        }

        Button("Copy Path") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(item.url.path, forType: .string)
        }

        Divider()

        Button("Move to Trash") {
            if selectedItem?.id == item.id {
                selectedItem = nil
            }
            viewModel.delete(item)
        }
    }
}

struct MediaGridCell: View {
    let item: MediaItem
    @ObservedObject var thumbnailProvider: ThumbnailProvider

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

            HStack {
                Text(item.type == .video ? "VIDEO" : "PHOTO")
                    .font(.caption2.bold())
                    .padding(5)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Spacer()
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
            thumbnailProvider.thumbnail(for: item.url, size: 300) { image in
                thumbnail = image
            }
        }
    }
}

struct MediaListRow: View {
    let item: MediaItem
    @ObservedObject var thumbnailProvider: ThumbnailProvider

    @State private var thumbnail: NSImage?

    private var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: item.fileSize, countStyle: .file)
    }

    private var formattedDate: String {
        guard let createdAt = item.createdAt else { return "Unknown date" }
        return createdAt.formatted(date: .abbreviated, time: .omitted)
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
                Text(item.filename)
                    .lineLimit(1)
                Text("\(item.type == .video ? "Video" : "Photo") • \(formattedDate) • \(formattedSize)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .onAppear {
            thumbnailProvider.thumbnail(for: item.url, size: 160) { image in
                thumbnail = image
            }
        }
    }
}

struct MediaViewer: View {
    let mediaItems: [MediaItem]
    let initialItem: MediaItem
    let onClose: () -> Void

    @State private var currentIndex: Int = 0
    @State private var player: AVPlayer?
    @State private var image: NSImage?
    @State private var isLoadingImage = false
    @State private var keyMonitor: Any?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(currentItem.filename)
                    .lineLimit(1)

                Spacer()

                Text("\(currentIndex + 1) / \(mediaItems.count)")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 14) {
                sideArrow(systemName: "chevron.left", disabled: currentIndex == 0) {
                    previous()
                }

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
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .gesture(
                    DragGesture(minimumDistance: 25)
                        .onEnded { value in
                            if value.translation.width < -40 {
                                next()
                            } else if value.translation.width > 40 {
                                previous()
                            }
                        }
                )

                sideArrow(systemName: "chevron.right", disabled: currentIndex == mediaItems.count - 1) {
                    next()
                }
            }
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 18)
        .onAppear {
            if let index = mediaItems.firstIndex(of: initialItem) {
                currentIndex = index
            }
            prepareCurrentItem()
            installKeyMonitor()
        }
        .onDisappear {
            player?.pause()
            removeKeyMonitor()
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
        if currentItem.type == .video {
            image = nil
            isLoadingImage = false
            player = AVPlayer(url: currentItem.url)
            player?.play()
        } else {
            player?.pause()
            player = nil
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

    private func prefetchNeighbors() {
        let neighbors = [currentIndex - 1, currentIndex + 1]
            .filter { mediaItems.indices.contains($0) }
            .map { mediaItems[$0] }

        for item in neighbors where item.type == .image {
            FullImageProvider.shared.prefetch(url: item.url)
        }
    }

    private func togglePlayback() {
        guard let player else { return }
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    private func replayCurrentVideo() {
        guard currentItem.type == .video, let player else { return }
        player.seek(to: .zero)
        player.play()
    }

    private func installKeyMonitor() {
        removeKeyMonitor()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 49: // Space
                togglePlayback()
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
