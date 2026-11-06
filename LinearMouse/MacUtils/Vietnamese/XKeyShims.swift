// Stand-ins for XKey app services the vendored engine references.
// MacUtils ships only the core typing engine: no dictionary download,
// user dictionary, iCloud sync or per-app smart switch.

import Foundation

final class SharedSettings {
    static let shared = SharedSettings()

    var modernStyle = true
    var spellCheckEnabled = false
    var restoreIfWrongSpelling = false
    var instantRestoreOnWrongSpelling = false

    func getMacrosData() -> Data? {
        nil
    }

    func getSmartSwitchData() -> Data? {
        nil
    }

    func updateSmartSwitchLanguage(bundleIdentifier _: String, language _: Int) -> Data? {
        nil
    }

    func isWordInUserDictionary(_: String) -> Bool {
        false
    }
}

final class VNDictionaryManager {
    static let shared = VNDictionaryManager()

    enum DictionaryStyle: String {
        case dauMoi = "DauMoi"
        case dauCu = "DauCu"
    }

    func isDictionaryLoaded(style _: DictionaryStyle = .dauMoi) -> Bool {
        false
    }

    func isValidWord(_: String, style _: DictionaryStyle = .dauMoi) -> Bool {
        true
    }
}

final class AppBehaviorDetector {
    static let shared = AppBehaviorDetector()

    func isInBrowserAddressBar() -> Bool {
        false
    }
}
