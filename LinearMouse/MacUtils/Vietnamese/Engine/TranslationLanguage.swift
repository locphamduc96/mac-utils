// Vendored from https://github.com/xmannv/xkey @ 398e78e (MIT License, see ThirdPartyNotices/xkey.txt).
// Keep local edits minimal so upstream fixes can be re-applied.

//
//  TranslationLanguage.swift
//  XKey
//
//  Flexible Translation Language Model
//  Supports unlimited languages via ISO 639-1 codes
//

import Foundation

// MARK: - Translation Language

/// A flexible language model that supports any ISO 639-1 language code
/// Instead of a hardcoded enum, this struct allows for:
/// - Preset popular languages with display names and flags
/// - Custom languages via ISO 639-1 codes (e.g., "pt" for Portuguese)
struct TranslationLanguage: Codable, Identifiable, Hashable, Equatable {
    let code: String           // ISO 639-1 code (e.g., "en", "vi", "auto")
    let displayName: String    // Human readable name
    let flag: String           // Emoji flag or icon
    
    var id: String { code }
    
    /// rawValue compatibility for existing code
    var rawValue: String { code }
    
    init(code: String, displayName: String, flag: String) {
        self.code = code.lowercased()
        self.displayName = displayName
        self.flag = flag
    }
    
    /// Initialize from raw code (for backward compatibility)
    init?(rawValue: String) {
        let code = rawValue.lowercased()
        
        // Try to find in presets first
        if let preset = TranslationLanguage.presets.first(where: { $0.code == code }) {
            self = preset
            return
        }
        
        // Create custom language with the code
        self = TranslationLanguage.custom(code: code)
    }
    
    // MARK: - Preset Languages
    
    /// Auto-detect language
    static let auto = TranslationLanguage(code: "auto", displayName: "Tự động nhận diện", flag: "🌐")
    
    /// Commonly used preset languages
    static let presets: [TranslationLanguage] = [
        auto,
        // Southeast Asia
        TranslationLanguage(code: "vi", displayName: "Tiếng Việt", flag: "🇻🇳"),
        TranslationLanguage(code: "th", displayName: "ไทย (Thai)", flag: "🇹🇭"),
        TranslationLanguage(code: "id", displayName: "Indonesia", flag: "🇮🇩"),
        TranslationLanguage(code: "ms", displayName: "Bahasa Melayu", flag: "🇲🇾"),
        TranslationLanguage(code: "tl", displayName: "Filipino/Tagalog", flag: "🇵🇭"),
        TranslationLanguage(code: "km", displayName: "ភាសាខ្មែរ (Khmer)", flag: "🇰🇭"),
        TranslationLanguage(code: "lo", displayName: "ລາວ (Lao)", flag: "🇱🇦"),
        TranslationLanguage(code: "my", displayName: "မြန်မာ (Burmese)", flag: "🇲🇲"),
        
        // East Asia
        TranslationLanguage(code: "zh", displayName: "中文 (Chinese Simplified)", flag: "🇨🇳"),
        TranslationLanguage(code: "zh-TW", displayName: "繁體中文 (Chinese Traditional)", flag: "🇹🇼"),
        TranslationLanguage(code: "ja", displayName: "日本語 (Japanese)", flag: "🇯🇵"),
        TranslationLanguage(code: "ko", displayName: "한국어 (Korean)", flag: "🇰🇷"),
        
        // Western Languages
        TranslationLanguage(code: "en", displayName: "English", flag: "🇺🇸"),
        TranslationLanguage(code: "fr", displayName: "Français", flag: "🇫🇷"),
        TranslationLanguage(code: "de", displayName: "Deutsch", flag: "🇩🇪"),
        TranslationLanguage(code: "es", displayName: "Español", flag: "🇪🇸"),
        TranslationLanguage(code: "pt", displayName: "Português", flag: "🇵🇹"),
        TranslationLanguage(code: "it", displayName: "Italiano", flag: "🇮🇹"),
        TranslationLanguage(code: "nl", displayName: "Nederlands", flag: "🇳🇱"),
        TranslationLanguage(code: "pl", displayName: "Polski", flag: "🇵🇱"),
        TranslationLanguage(code: "ru", displayName: "Русский", flag: "🇷🇺"),
        TranslationLanguage(code: "uk", displayName: "Українська", flag: "🇺🇦"),
        
        // Middle East & South Asia
        TranslationLanguage(code: "ar", displayName: "العربية (Arabic)", flag: "🇸🇦"),
        TranslationLanguage(code: "he", displayName: "עברית (Hebrew)", flag: "🇮🇱"),
        TranslationLanguage(code: "fa", displayName: "فارسی (Persian)", flag: "🇮🇷"),
        TranslationLanguage(code: "hi", displayName: "हिन्दी (Hindi)", flag: "🇮🇳"),
        TranslationLanguage(code: "bn", displayName: "বাংলা (Bengali)", flag: "🇧🇩"),
        TranslationLanguage(code: "ta", displayName: "தமிழ் (Tamil)", flag: "🇮🇳"),
        TranslationLanguage(code: "ur", displayName: "اردو (Urdu)", flag: "🇵🇰"),
        
        // Other popular
        TranslationLanguage(code: "tr", displayName: "Türkçe", flag: "🇹🇷"),
        TranslationLanguage(code: "el", displayName: "Ελληνικά (Greek)", flag: "🇬🇷"),
        TranslationLanguage(code: "cs", displayName: "Čeština (Czech)", flag: "🇨🇿"),
        TranslationLanguage(code: "sv", displayName: "Svenska (Swedish)", flag: "🇸🇪"),
        TranslationLanguage(code: "da", displayName: "Dansk (Danish)", flag: "🇩🇰"),
        TranslationLanguage(code: "fi", displayName: "Suomi (Finnish)", flag: "🇫🇮"),
        TranslationLanguage(code: "no", displayName: "Norsk (Norwegian)", flag: "🇳🇴"),
        TranslationLanguage(code: "hu", displayName: "Magyar (Hungarian)", flag: "🇭🇺"),
        TranslationLanguage(code: "ro", displayName: "Română (Romanian)", flag: "🇷🇴"),
    ]
    
    /// Source language presets (includes auto-detect)
    static var sourcePresets: [TranslationLanguage] {
        return presets
    }
    
    /// Target language presets (excludes auto-detect)
    static var targetPresets: [TranslationLanguage] {
        return presets.filter { $0.code != "auto" }
    }
    
    /// Create a custom language from ISO 639-1 code
    /// For languages not in the preset list
    static func custom(code: String) -> TranslationLanguage {
        let cleanCode = code.lowercased().trimmingCharacters(in: .whitespaces)
        return TranslationLanguage(
            code: cleanCode,
            displayName: cleanCode.uppercased(),
            flag: "🌍"
        )
    }
    
    /// Quick access to common languages
    static let vietnamese = TranslationLanguage(code: "vi", displayName: "Tiếng Việt", flag: "🇻🇳")
    static let english = TranslationLanguage(code: "en", displayName: "English", flag: "🇺🇸")
    static let chinese = TranslationLanguage(code: "zh", displayName: "中文", flag: "🇨🇳")
    static let japanese = TranslationLanguage(code: "ja", displayName: "日本語", flag: "🇯🇵")
    static let korean = TranslationLanguage(code: "ko", displayName: "한국어", flag: "🇰🇷")
    
    // MARK: - Lookup
    
    /// Find a language by code (returns custom language if not found in presets)
    static func find(byCode code: String) -> TranslationLanguage {
        let cleanCode = code.lowercased()
        return presets.first { $0.code == cleanCode } ?? custom(code: cleanCode)
    }
    
    /// Check if this is the auto-detect language
    var isAuto: Bool {
        return code == "auto"
    }
    
    /// Check if this is a custom (non-preset) language
    var isCustom: Bool {
        return !TranslationLanguage.presets.contains(where: { $0.code == code })
    }
}

// MARK: - CaseIterable-like behavior (for existing code compatibility)

extension TranslationLanguage {
    /// For compatibility with existing code that uses allCases
    static var allCases: [TranslationLanguage] {
        return presets
    }
}
