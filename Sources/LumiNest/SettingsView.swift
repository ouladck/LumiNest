import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension Notification.Name {
    static let luminestClearCaches = Notification.Name("luminest.clearCaches")
}

struct SettingsView: View {
    @AppStorage(SettingsKeys.defaultLayout) private var defaultLayout = LayoutMode.grid.rawValue
    @AppStorage(SettingsKeys.defaultSort) private var defaultSort = SortMode.name.rawValue
    @AppStorage(SettingsKeys.openLastFolderOnLaunch) private var openLastFolderOnLaunch = true
    @AppStorage(SettingsKeys.uiLanguage) private var uiLanguage = UILanguageOption.system.rawValue
    @AppStorage(SettingsKeys.dateFormat) private var dateFormat = DateFormatOption.system.rawValue

    @AppStorage(SettingsKeys.viewerAutoplay) private var viewerAutoplay = true
    @AppStorage(SettingsKeys.viewerDetailsExpandedByDefault) private var detailsExpandedByDefault = false
    @AppStorage(SettingsKeys.viewerLoopVideo) private var viewerLoopVideo = false
    @AppStorage(SettingsKeys.viewerSwipeSensitivity) private var swipeSensitivity: Double = 40

    @AppStorage(SettingsKeys.thumbnailQuality) private var thumbnailQuality = ThumbnailQualityOption.medium.rawValue
    @AppStorage(SettingsKeys.thumbnailCacheLimit) private var thumbnailCacheLimit = ThumbnailCacheLimitOption.medium.rawValue
    @AppStorage(SettingsKeys.preloadNeighbors) private var preloadNeighbors = true
    @AppStorage(SettingsKeys.scanPriority) private var scanPriority = ScanPriorityOption.fast.rawValue

    @AppStorage(SettingsKeys.confirmFavoriteRemoval) private var confirmFavoriteRemoval = false
    @AppStorage(SettingsKeys.confirmAlbumDelete) private var confirmAlbumDelete = true
    @AppStorage(SettingsKeys.autoSelectCreatedAlbum) private var autoSelectCreatedAlbum = true
    @AppStorage(SettingsKeys.showFavoriteStar) private var showFavoriteStar = true

    @AppStorage(SettingsKeys.confirmMoveToTrash) private var confirmMoveToTrash = true
    @AppStorage(SettingsKeys.showFullPath) private var showFullPath = true
    @AppStorage(SettingsKeys.copyPathFormat) private var copyPathFormat = CopyPathFormatOption.absolute.rawValue

    @State private var infoMessage: String?

    var body: some View {
        TabView {
            generalTab
                .tabItem { Text("General") }

            viewerTab
                .tabItem { Text("Viewer") }

            performanceTab
                .tabItem { Text("Performance") }

            albumsPrivacyTab
                .tabItem { Text("Albums & Privacy") }

            diagnosticsTab
                .tabItem { Text("Diagnostics") }
        }
        .padding(16)
        .frame(minWidth: 760, minHeight: 520)
    }

    private var generalTab: some View {
        Form {
            Picker("Default start view", selection: $defaultLayout) {
                Text("Grid").tag(LayoutMode.grid.rawValue)
                Text("List").tag(LayoutMode.list.rawValue)
            }

            Picker("Default sort", selection: $defaultSort) {
                ForEach(SortMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode.rawValue)
                }
            }

            Toggle("Open last folder on launch", isOn: $openLastFolderOnLaunch)

            Picker("UI language", selection: $uiLanguage) {
                ForEach(UILanguageOption.allCases) { option in
                    Text(option.rawValue).tag(option.rawValue)
                }
            }

            Picker("Date format", selection: $dateFormat) {
                ForEach(DateFormatOption.allCases) { option in
                    Text(option.rawValue).tag(option.rawValue)
                }
            }
        }
    }

    private var viewerTab: some View {
        Form {
            Toggle("Autoplay videos in preview", isOn: $viewerAutoplay)
            Toggle("Details expanded by default", isOn: $detailsExpandedByDefault)
            Toggle("Loop video when it ends", isOn: $viewerLoopVideo)

            VStack(alignment: .leading, spacing: 6) {
                Text("Swipe sensitivity (\(Int(swipeSensitivity)))")
                Slider(value: $swipeSensitivity, in: 20...120, step: 5)
            }
        }
    }

    private var performanceTab: some View {
        Form {
            Picker("Thumbnail quality", selection: $thumbnailQuality) {
                ForEach(ThumbnailQualityOption.allCases) { option in
                    Text(option.rawValue).tag(option.rawValue)
                }
            }

            Picker("Thumbnail cache size", selection: $thumbnailCacheLimit) {
                ForEach(ThumbnailCacheLimitOption.allCases) { option in
                    Text(option.rawValue).tag(option.rawValue)
                }
            }

            Toggle("Preload next/previous media", isOn: $preloadNeighbors)

            Picker("Background scan priority", selection: $scanPriority) {
                ForEach(ScanPriorityOption.allCases) { option in
                    Text(option.rawValue).tag(option.rawValue)
                }
            }
        }
    }

    private var albumsPrivacyTab: some View {
        Form {
            Toggle("Confirm before removing favorite", isOn: $confirmFavoriteRemoval)
            Toggle("Confirm before deleting album", isOn: $confirmAlbumDelete)
            Toggle("Auto-select album after creation", isOn: $autoSelectCreatedAlbum)
            Toggle("Show favorite star in gallery", isOn: $showFavoriteStar)

            Divider()

            Toggle("Confirm before move to Trash", isOn: $confirmMoveToTrash)
            Toggle("Show full selected-folder path", isOn: $showFullPath)

            Picker("Copy path format", selection: $copyPathFormat) {
                ForEach(CopyPathFormatOption.allCases) { option in
                    Text(option.rawValue).tag(option.rawValue)
                }
            }
        }
    }

    private var diagnosticsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Version \(appVersion) (\(buildNumber))")
                .font(.headline)

            HStack(spacing: 12) {
                Button("Clear Caches") {
                    FullImageProvider.shared.clearCache()
                    NotificationCenter.default.post(name: .luminestClearCaches, object: nil)
                    infoMessage = "Caches cleared."
                }

                Button("Reset All Settings") {
                    resetSettings()
                    infoMessage = "Settings reset to defaults."
                }

                Button("Export Diagnostics") {
                    exportDiagnostics()
                }
            }

            if let infoMessage {
                Text(infoMessage)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    private func resetSettings() {
        let defaults = UserDefaults.standard
        let keys = [
            SettingsKeys.defaultLayout, SettingsKeys.defaultSort, SettingsKeys.openLastFolderOnLaunch,
            SettingsKeys.uiLanguage, SettingsKeys.dateFormat,
            SettingsKeys.viewerAutoplay, SettingsKeys.viewerDetailsExpandedByDefault,
            SettingsKeys.viewerLoopVideo, SettingsKeys.viewerSwipeSensitivity,
            SettingsKeys.thumbnailQuality, SettingsKeys.thumbnailCacheLimit,
            SettingsKeys.preloadNeighbors, SettingsKeys.scanPriority,
            SettingsKeys.confirmFavoriteRemoval, SettingsKeys.confirmAlbumDelete,
            SettingsKeys.autoSelectCreatedAlbum, SettingsKeys.showFavoriteStar,
            SettingsKeys.confirmMoveToTrash, SettingsKeys.showFullPath, SettingsKeys.copyPathFormat,
            "gallery.filter", "gallery.sort", "gallery.layout",
            "gallery.albumScope", "gallery.selectedCollection"
        ]

        for key in keys {
            defaults.removeObject(forKey: key)
        }
    }

    private func exportDiagnostics() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "luminest-diagnostics.txt"
        panel.allowedContentTypes = [.plainText]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let defaults = UserDefaults.standard
        let payload = """
        LumiNest Diagnostics
        Date: \(Date())
        Version: \(appVersion) (\(buildNumber))

        Stored Preferences:
        - defaultLayout: \(defaults.string(forKey: SettingsKeys.defaultLayout) ?? "grid")
        - defaultSort: \(defaults.string(forKey: SettingsKeys.defaultSort) ?? "name")
        - openLastFolderOnLaunch: \(defaults.object(forKey: SettingsKeys.openLastFolderOnLaunch) as? Bool ?? true)
        - viewerAutoplay: \(defaults.object(forKey: SettingsKeys.viewerAutoplay) as? Bool ?? true)
        - viewerDetailsExpandedByDefault: \(defaults.object(forKey: SettingsKeys.viewerDetailsExpandedByDefault) as? Bool ?? false)
        - viewerLoopVideo: \(defaults.object(forKey: SettingsKeys.viewerLoopVideo) as? Bool ?? false)
        - swipeSensitivity: \(defaults.object(forKey: SettingsKeys.viewerSwipeSensitivity) as? Double ?? 40)
        - thumbnailQuality: \(defaults.string(forKey: SettingsKeys.thumbnailQuality) ?? "medium")
        - thumbnailCacheLimit: \(defaults.string(forKey: SettingsKeys.thumbnailCacheLimit) ?? "medium")
        - preloadNeighbors: \(defaults.object(forKey: SettingsKeys.preloadNeighbors) as? Bool ?? true)
        - scanPriority: \(defaults.string(forKey: SettingsKeys.scanPriority) ?? "fast")
        """

        do {
            try payload.write(to: url, atomically: true, encoding: .utf8)
            infoMessage = "Diagnostics exported."
        } catch {
            infoMessage = "Failed to export diagnostics."
        }
    }
}
