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
    @AppStorage(SettingsKeys.defaultMediaRootPath) private var defaultMediaRootPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures", isDirectory: true).path
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

    @State private var settingsSearch = ""
    @State private var infoMessage: String?

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(L10n.s("settings.search"), text: $settingsSearch)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if let infoMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(infoMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            TabView {
                generalTab
                    .tabItem { Text(L10n.s("settings.tab.general")) }

                viewerTab
                    .tabItem { Text(L10n.s("settings.tab.viewer")) }

                performanceTab
                    .tabItem { Text(L10n.s("settings.tab.performance")) }

                albumsPrivacyTab
                    .tabItem { Text(L10n.s("settings.tab.albums_privacy")) }

                diagnosticsTab
                    .tabItem { Text(L10n.s("settings.tab.diagnostics")) }
            }
        }
        .padding(14)
        .frame(minWidth: 760, minHeight: 520)
    }

    private var generalTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                settingsCard(
                    title: L10n.s("settings.general.startup.title"),
                    subtitle: L10n.s("settings.general.startup.subtitle"),
                    keywords: ["startup", "default", "layout", "sort", "open", "launch"]
                ) {
                    Picker(L10n.s("settings.general.default_view"), selection: $defaultLayout) {
                        Text(L10n.s("common.grid")).tag(LayoutMode.grid.rawValue)
                        Text(L10n.s("common.list")).tag(LayoutMode.list.rawValue)
                    }

                    Picker(L10n.s("settings.general.default_sort"), selection: $defaultSort) {
                        ForEach(SortMode.allCases) { mode in
                            Text(mode.localizedName).tag(mode.rawValue)
                        }
                    }

                    Toggle(L10n.s("settings.general.open_last_folder"), isOn: $openLastFolderOnLaunch)
                }

                settingsCard(
                    title: L10n.s("settings.general.library_root.title"),
                    subtitle: L10n.s("settings.general.library_root.subtitle"),
                    keywords: ["library", "root", "folder", "path", "default"]
                ) {
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.s("settings.general.default_media_root"))
                                .font(.callout.weight(.semibold))
                            Text(defaultMediaRootPath)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Spacer(minLength: 0)

                        Button(L10n.s("common.choose")) {
                            chooseDefaultMediaRoot()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                settingsCard(
                    title: L10n.s("settings.general.locale.title"),
                    subtitle: L10n.s("settings.general.locale.subtitle"),
                    keywords: ["language", "date", "format", "locale"]
                ) {
                    Picker(L10n.s("settings.general.ui_language"), selection: $uiLanguage) {
                        ForEach(UILanguageOption.allCases) { option in
                            Text(option.displayName).tag(option.rawValue)
                        }
                    }

                    Picker(L10n.s("settings.general.date_format"), selection: $dateFormat) {
                        ForEach(DateFormatOption.allCases) { option in
                            Text(option.rawValue).tag(option.rawValue)
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button(L10n.s("settings.reset_tab")) {
                        resetGeneralTab()
                        infoMessage = L10n.s("settings.message.general_reset")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var viewerTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                settingsCard(
                    title: L10n.s("settings.viewer.playback.title"),
                    subtitle: L10n.s("settings.viewer.playback.subtitle"),
                    keywords: ["viewer", "playback", "autoplay", "loop", "video"]
                ) {
                    Toggle(L10n.s("settings.viewer.autoplay"), isOn: $viewerAutoplay)
                    Toggle(L10n.s("settings.viewer.loop"), isOn: $viewerLoopVideo)
                }

                settingsCard(
                    title: L10n.s("settings.viewer.navigation.title"),
                    subtitle: L10n.s("settings.viewer.navigation.subtitle"),
                    keywords: ["viewer", "swipe", "navigation", "sensitivity"]
                ) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(L10n.s("settings.viewer.swipe_sensitivity"))
                            Spacer()
                            Text("\(Int(swipeSensitivity))")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $swipeSensitivity, in: 20...120, step: 5)
                    }
                }

                settingsCard(
                    title: L10n.s("settings.viewer.metadata.title"),
                    subtitle: L10n.s("settings.viewer.metadata.subtitle"),
                    keywords: ["viewer", "details", "metadata"]
                ) {
                    Toggle(L10n.s("settings.viewer.details_expanded"), isOn: $detailsExpandedByDefault)
                }

                HStack {
                    Spacer()
                    Button(L10n.s("settings.reset_tab")) {
                        resetViewerTab()
                        infoMessage = L10n.s("settings.message.viewer_reset")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var performanceTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                settingsCard(
                    title: L10n.s("settings.performance.thumbnails.title"),
                    subtitle: L10n.s("settings.performance.thumbnails.subtitle"),
                    keywords: ["performance", "thumbnail", "quality", "cache"]
                ) {
                    Picker(L10n.s("settings.performance.thumbnail_quality"), selection: $thumbnailQuality) {
                        ForEach(ThumbnailQualityOption.allCases) { option in
                            Text(option.rawValue).tag(option.rawValue)
                        }
                    }

                    Picker(L10n.s("settings.performance.thumbnail_cache_size"), selection: $thumbnailCacheLimit) {
                        ForEach(ThumbnailCacheLimitOption.allCases) { option in
                            Text(option.rawValue).tag(option.rawValue)
                        }
                    }
                }

                settingsCard(
                    title: L10n.s("settings.performance.background.title"),
                    subtitle: L10n.s("settings.performance.background.subtitle"),
                    keywords: ["performance", "scan", "priority", "preload"]
                ) {
                    Toggle(L10n.s("settings.performance.preload_neighbors"), isOn: $preloadNeighbors)

                    Picker(L10n.s("settings.performance.scan_priority"), selection: $scanPriority) {
                        ForEach(ScanPriorityOption.allCases) { option in
                            Text(option.rawValue).tag(option.rawValue)
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button(L10n.s("settings.reset_tab")) {
                        resetPerformanceTab()
                        infoMessage = L10n.s("settings.message.performance_reset")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var albumsPrivacyTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                settingsCard(
                    title: L10n.s("settings.albums_favorites.title"),
                    subtitle: L10n.s("settings.albums_favorites.subtitle"),
                    keywords: ["album", "favorite", "confirm", "star"]
                ) {
                    Toggle(L10n.s("settings.albums.confirm_remove_favorite"), isOn: $confirmFavoriteRemoval)
                    Toggle(L10n.s("settings.albums.confirm_delete_album"), isOn: $confirmAlbumDelete)
                    Toggle(L10n.s("settings.albums.auto_select_created"), isOn: $autoSelectCreatedAlbum)
                    Toggle(L10n.s("settings.albums.show_favorite_star"), isOn: $showFavoriteStar)
                }

                settingsCard(
                    title: L10n.s("settings.file_path_actions.title"),
                    subtitle: L10n.s("settings.file_path_actions.subtitle"),
                    keywords: ["trash", "path", "copy", "privacy"]
                ) {
                    Toggle(L10n.s("settings.file.confirm_move_trash"), isOn: $confirmMoveToTrash)
                    Toggle(L10n.s("settings.file.show_full_path"), isOn: $showFullPath)

                    Picker(L10n.s("settings.file.copy_path_format"), selection: $copyPathFormat) {
                        ForEach(CopyPathFormatOption.allCases) { option in
                            Text(option.rawValue).tag(option.rawValue)
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button(L10n.s("settings.reset_tab")) {
                        resetAlbumsPrivacyTab()
                        infoMessage = L10n.s("settings.message.albums_privacy_reset")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var diagnosticsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                settingsCard(
                    title: L10n.s("settings.diagnostics.application.title"),
                    subtitle: L10n.s("settings.diagnostics.application.subtitle"),
                    keywords: ["diagnostics", "version", "build", "app"]
                ) {
                    Text("Version \(appVersion) (\(buildNumber))")
                        .font(.headline)
                }

                settingsCard(
                    title: L10n.s("settings.diagnostics.maintenance.title"),
                    subtitle: L10n.s("settings.diagnostics.maintenance.subtitle"),
                    keywords: ["diagnostics", "cache", "clear", "export"]
                ) {
                    HStack(spacing: 12) {
                        Button(L10n.s("settings.diagnostics.clear_caches")) {
                            FullImageProvider.shared.clearCache()
                            NotificationCenter.default.post(name: .luminestClearCaches, object: nil)
                            infoMessage = L10n.s("settings.message.caches_cleared")
                        }

                        Button(L10n.s("settings.diagnostics.export_diagnostics")) {
                            exportDiagnostics()
                        }
                    }
                }

                settingsCard(
                    title: L10n.s("settings.diagnostics.danger_zone.title"),
                    subtitle: L10n.s("settings.diagnostics.danger_zone.subtitle"),
                    keywords: ["reset", "danger", "diagnostics", "defaults"]
                ) {
                    Button(L10n.s("settings.diagnostics.reset_all")) {
                        resetSettings()
                        infoMessage = L10n.s("settings.message.all_reset")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
            SettingsKeys.defaultMediaRootPath,
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

    private func resetGeneralTab() {
        let defaults = UserDefaults.standard
        let keys = [
            SettingsKeys.defaultLayout, SettingsKeys.defaultSort, SettingsKeys.openLastFolderOnLaunch,
            SettingsKeys.defaultMediaRootPath, SettingsKeys.uiLanguage, SettingsKeys.dateFormat
        ]
        for key in keys { defaults.removeObject(forKey: key) }
    }

    private func resetViewerTab() {
        let defaults = UserDefaults.standard
        let keys = [
            SettingsKeys.viewerAutoplay, SettingsKeys.viewerDetailsExpandedByDefault,
            SettingsKeys.viewerLoopVideo, SettingsKeys.viewerSwipeSensitivity
        ]
        for key in keys { defaults.removeObject(forKey: key) }
    }

    private func resetPerformanceTab() {
        let defaults = UserDefaults.standard
        let keys = [
            SettingsKeys.thumbnailQuality, SettingsKeys.thumbnailCacheLimit,
            SettingsKeys.preloadNeighbors, SettingsKeys.scanPriority
        ]
        for key in keys { defaults.removeObject(forKey: key) }
    }

    private func resetAlbumsPrivacyTab() {
        let defaults = UserDefaults.standard
        let keys = [
            SettingsKeys.confirmFavoriteRemoval, SettingsKeys.confirmAlbumDelete,
            SettingsKeys.autoSelectCreatedAlbum, SettingsKeys.showFavoriteStar,
            SettingsKeys.confirmMoveToTrash, SettingsKeys.showFullPath, SettingsKeys.copyPathFormat
        ]
        for key in keys { defaults.removeObject(forKey: key) }
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
        - defaultMediaRootPath: \(defaults.string(forKey: SettingsKeys.defaultMediaRootPath) ?? "~/Pictures")
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

    private func chooseDefaultMediaRoot() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.title = "Default Media Root"
        panel.directoryURL = URL(fileURLWithPath: defaultMediaRootPath)

        guard panel.runModal() == .OK, let url = panel.url else { return }
        defaultMediaRootPath = url.path
    }

    @ViewBuilder
    private func settingsCard<Content: View>(
        title: String,
        subtitle: String,
        keywords: [String],
        @ViewBuilder content: () -> Content
    ) -> some View {
        if shouldShow(keywords: keywords + [title, subtitle]) {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Divider()
                content()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func shouldShow(keywords: [String]) -> Bool {
        let query = settingsSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return true }
        return keywords.contains { $0.lowercased().contains(query) }
    }
}
