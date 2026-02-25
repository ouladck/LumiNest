import Foundation
import CoreGraphics

enum SettingsKeys {
    static let defaultLayout = "settings.defaultLayout"
    static let defaultSort = "settings.defaultSort"
    static let openLastFolderOnLaunch = "settings.openLastFolderOnLaunch"
    static let defaultMediaRootPath = "settings.defaultMediaRootPath"
    static let uiLanguage = "settings.uiLanguage"
    static let dateFormat = "settings.dateFormat"

    static let viewerAutoplay = "settings.viewerAutoplay"
    static let viewerDetailsExpandedByDefault = "settings.viewerDetailsExpandedByDefault"
    static let viewerLoopVideo = "settings.viewerLoopVideo"
    static let viewerSwipeSensitivity = "settings.viewerSwipeSensitivity"

    static let thumbnailQuality = "settings.thumbnailQuality"
    static let thumbnailCacheLimit = "settings.thumbnailCacheLimit"
    static let preloadNeighbors = "settings.preloadNeighbors"
    static let scanPriority = "settings.scanPriority"

    static let confirmFavoriteRemoval = "settings.confirmFavoriteRemoval"
    static let confirmAlbumDelete = "settings.confirmAlbumDelete"
    static let autoSelectCreatedAlbum = "settings.autoSelectCreatedAlbum"
    static let showFavoriteStar = "settings.showFavoriteStar"

    static let confirmMoveToTrash = "settings.confirmMoveToTrash"
    static let showFullPath = "settings.showFullPath"
    static let copyPathFormat = "settings.copyPathFormat"
}

enum UILanguageOption: String, CaseIterable, Identifiable {
    case system = "System"
    case english = "English"
    case french = "French"
    case spanish = "Spanish"
    case german = "German"
    case italian = "Italian"
    case portugueseBrazil = "Portuguese (Brazil)"
    case russian = "Russian"
    case japanese = "Japanese"
    case chineseSimplified = "Chinese (Simplified)"
    case arabic = "Arabic"
    case tamazight = "ⵜⴰⵎⴰⵣⵉⵖⵜ"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .english: return "English"
        case .french: return "Français"
        case .spanish: return "Español"
        case .german: return "Deutsch"
        case .italian: return "Italiano"
        case .portugueseBrazil: return "Português (Brasil)"
        case .russian: return "Русский"
        case .japanese: return "日本語"
        case .chineseSimplified: return "简体中文"
        case .arabic: return "العربية"
        case .tamazight: return "ⵜⴰⵎⴰⵣⵉⵖⵜ"
        }
    }

    var localizationCode: String? {
        switch self {
        case .system:
            return nil
        case .english:
            return "en"
        case .french:
            return "fr"
        case .spanish:
            return "es"
        case .german:
            return "de"
        case .italian:
            return "it"
        case .portugueseBrazil:
            return "pt-BR"
        case .russian:
            return "ru"
        case .japanese:
            return "ja"
        case .chineseSimplified:
            return "zh-Hans"
        case .arabic:
            return "ar"
        case .tamazight:
            return "zgh"
        }
    }
}

enum DateFormatOption: String, CaseIterable, Identifiable {
    case system = "System"
    case us = "MM/DD/YYYY"
    case eu = "DD/MM/YYYY"
    case iso = "YYYY-MM-DD"

    var id: String { rawValue }
}

enum ThumbnailQualityOption: String, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var id: String { rawValue }

    var pixelSize: CGFloat {
        switch self {
        case .low: return 140
        case .medium: return 220
        case .high: return 320
        }
    }
}

enum ScanPriorityOption: String, CaseIterable, Identifiable {
    case background = "Background"
    case utility = "Balanced"
    case fast = "Fast"

    var id: String { rawValue }

    var qos: DispatchQoS.QoSClass {
        switch self {
        case .background: return .background
        case .utility: return .utility
        case .fast: return .userInitiated
        }
    }
}

enum CopyPathFormatOption: String, CaseIterable, Identifiable {
    case absolute = "Absolute"
    case relative = "Relative to Folder"

    var id: String { rawValue }
}

enum ThumbnailCacheLimitOption: String, CaseIterable, Identifiable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"

    var id: String { rawValue }

    var countLimit: Int {
        switch self {
        case .small: return 120
        case .medium: return 320
        case .large: return 800
        }
    }
}
