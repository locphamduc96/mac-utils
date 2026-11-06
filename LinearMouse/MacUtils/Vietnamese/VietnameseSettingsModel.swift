// MIT License
// Copyright (c) 2026 MacUtils

import Carbon.HIToolbox
import CoreGraphics
import Defaults

/// Not Codable: Defaults then stores the plain raw value, which the input method process reads directly.
enum VietnameseInputMethod: String, CaseIterable, Defaults.Serializable {
    case telex
    case vni
    case simpleTelex

    var title: String {
        switch self {
        case .telex:
            return "Telex"
        case .vni:
            return "VNI"
        case .simpleTelex:
            return "Telex giản lược (w không thành ư)"
        }
    }

    var engineValue: VietInputMethod {
        switch self {
        case .telex:
            return .telex
        case .vni:
            return .vni
        case .simpleTelex:
            return .simpleTelex
        }
    }
}

extension VietCodeTable: Defaults.Serializable {
    var title: String {
        switch self {
        case .unicode:
            return "Unicode"
        case .tcvn3:
            return "TCVN3 (ABC)"
        case .vniWindows:
            return "VNI-Windows"
        }
    }
}

enum VietnameseToggleHotkey: String, CaseIterable, Defaults.Serializable {
    /// Press and release ⌃⇧ with no other key, like Unikey / GoTiengViet.
    case controlShift
    case optionZ
    case controlSpace

    var title: String {
        switch self {
        case .controlShift:
            return "⌃⇧ (Control + Shift)"
        case .optionZ:
            return "⌥Z (Option + Z)"
        case .controlSpace:
            return "⌃Space (Control + Space)"
        }
    }

    var shortTitle: String {
        switch self {
        case .controlShift:
            return "⌃⇧"
        case .optionZ:
            return "⌥Z"
        case .controlSpace:
            return "⌃Space"
        }
    }

    /// Key-based shortcuts: key code and the exact modifiers.
    var keyShortcut: (keyCode: Int64, flags: CGEventFlags)? {
        switch self {
        case .controlShift:
            return nil
        case .optionZ:
            return (Int64(kVK_ANSI_Z), .maskAlternate)
        case .controlSpace:
            return (Int64(kVK_Space), .maskControl)
        }
    }
}

enum VietnameseInjectionMode: String, CaseIterable, Codable {
    /// Paced for terminals, immediate elsewhere.
    case auto
    case immediate
    case paced
    case slower
    case slowest

    var title: String {
        switch self {
        case .auto:
            return "Tự động"
        case .immediate:
            return "Nhanh"
        case .paced:
            return "Chậm"
        case .slower:
            return "Rất chậm"
        case .slowest:
            return "Cực chậm"
        }
    }

    /// Multiplier for the paced delays; nil means immediate injection.
    var pacing: UInt32? {
        switch self {
        case .auto, .paced:
            return 1
        case .immediate:
            return nil
        case .slower:
            return 2
        case .slowest:
            return 4
        }
    }
}

struct VietnameseMacro: Codable, Hashable, Defaults.Serializable, Identifiable {
    var id = UUID()
    var shortcut: String
    var expansion: String
}

/// Per-app behaviour, keyed by bundle id.
struct VietnameseAppRule: Codable, Hashable, Defaults.Serializable, Identifiable {
    var bundleID: String
    var name: String
    /// Always English in this app.
    var excluded = false
    var injection = VietnameseInjectionMode.auto

    var id: String {
        bundleID
    }
}

extension Defaults.Keys {
    static let vietnameseModuleEnabled = Key<Bool>("macUtils.vietnamese.moduleEnabled", default: true)
    static let vietnameseTypingOn = Key<Bool>("macUtils.vietnamese.typingOn", default: true)
    static let vietnameseInputMethod = Key<VietnameseInputMethod>(
        "macUtils.vietnamese.inputMethod",
        default: .telex
    )
    static let vietnameseModernStyle = Key<Bool>("macUtils.vietnamese.modernStyle", default: false)
    static let vietnameseRestoreEnglish = Key<Bool>("macUtils.vietnamese.restoreEnglish", default: true)
    static let vietnameseCodeTable = Key<VietCodeTable>("macUtils.vietnamese.codeTable", default: .unicode)
    static let vietnameseToggleHotkey = Key<VietnameseToggleHotkey>(
        "macUtils.vietnamese.toggleHotkey",
        default: .controlShift
    )
    static let vietnameseRememberPerApp = Key<Bool>("macUtils.vietnamese.rememberPerApp", default: false)
    static let vietnamesePerAppTyping = Key<[String: Bool]>("macUtils.vietnamese.perAppTyping", default: [:])
    static let vietnameseMacrosEnabled = Key<Bool>("macUtils.vietnamese.macrosEnabled", default: true)
    static let vietnameseMacros = Key<[VietnameseMacro]>("macUtils.vietnamese.macros", default: [])
    static let vietnameseAppRules = Key<[VietnameseAppRule]>("macUtils.vietnamese.appRules", default: [])
}
