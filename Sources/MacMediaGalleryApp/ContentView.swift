import AVKit
import AppKit
import SwiftUI

struct ContentView: View {
    enum LayoutMode: String, CaseIterable, Identifiable {
        case grid = "Grid"
        case list = "List"

        var id: String { rawValue }
    }

    @StateObject private var viewModel = GalleryViewModel()
    @StateObject private var thumbnailProvider = ThumbnailProvider()

    @State private var layoutMode: LayoutMode = .grid
    @State private var selectedIndex: Int?

    var body: some View {
        VStack(spacing: 16) {
            header

            if viewModel.mediaItems.isEmpty {
                emptyState
            } else {
                if layoutMode == .grid {
                    gridView
                } else {
                    listView
                }
            }
        }
        .padding(16)
        .sheet(item: selectedMediaBinding) { media in
            MediaViewer(
                mediaItems: viewModel.mediaItems,
                initialItem: media
            )
        }
    }

    private var header: some View {
        HStack {
            Button("Select Folder") {
                viewModel.pickFolder()
            }

            if let folder = viewModel.selectedFolder {
                Text(folder.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Picker("View", selection: $layoutMode) {
                ForEach(LayoutMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
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
                ForEach(Array(viewModel.mediaItems.enumerated()), id: \.1.id) { index, item in
                    MediaGridCell(item: item, thumbnailProvider: thumbnailProvider)
                        .onTapGesture {
                            selectedIndex = index
                        }
                }
            }
            .padding(.top, 4)
        }
    }

    private var listView: some View {
        List {
            ForEach(Array(viewModel.mediaItems.enumerated()), id: \.1.id) { index, item in
                MediaListRow(item: item, thumbnailProvider: thumbnailProvider)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedIndex = index
                    }
            }
        }
        .listStyle(.inset)
    }

    private var selectedMediaBinding: Binding<MediaItem?> {
        Binding<MediaItem?>(
            get: {
                guard let index = selectedIndex, viewModel.mediaItems.indices.contains(index) else {
                    return nil
                }
                return viewModel.mediaItems[index]
            },
            set: { newValue in
                if newValue == nil {
                    selectedIndex = nil
                }
            }
        )
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
                Text(item.type == .video ? "Video" : "Photo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

    @State private var currentIndex: Int = 0
    @State private var player: AVPlayer?

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Previous") { previous() }
                    .disabled(currentIndex == 0)

                Button("Next") { next() }
                    .disabled(currentIndex == mediaItems.count - 1)

                Spacer()

                Text(currentItem.filename)
                    .lineLimit(1)

                Spacer()

                Text("\(currentIndex + 1) / \(mediaItems.count)")
                    .foregroundStyle(.secondary)
            }

            Group {
                if currentItem.type == .image {
                    if let image = NSImage(contentsOf: currentItem.url) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Text("Could not open image")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    if let player {
                        VideoPlayer(player: player)
                            .onAppear { player.play() }
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
        }
        .padding()
        .frame(minWidth: 900, minHeight: 650)
        .onAppear {
            if let index = mediaItems.firstIndex(of: initialItem) {
                currentIndex = index
                preparePlayer()
            }
        }
        .onChange(of: currentIndex) { _ in
            preparePlayer()
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

    private func preparePlayer() {
        if currentItem.type == .video {
            player = AVPlayer(url: currentItem.url)
            player?.play()
        } else {
            player?.pause()
            player = nil
        }
    }
}
