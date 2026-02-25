import Foundation

enum L10n {
    static func s(_ key: String) -> String {
        let defaults = UserDefaults.standard
        let selectedRaw = defaults.string(forKey: SettingsKeys.uiLanguage) ?? UILanguageOption.system.rawValue
        let selected = UILanguageOption(rawValue: selectedRaw) ?? .system

        guard let code = selected.localizationCode else {
            return NSLocalizedString(key, bundle: .module, comment: "")
        }

        if let path = Bundle.module.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: nil, table: nil)
        }

        return NSLocalizedString(key, bundle: .module, comment: "")
    }
}
