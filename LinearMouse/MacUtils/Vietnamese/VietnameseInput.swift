// MIT License
// Copyright (c) 2026 MacUtils

import AppKit
import Combine
import Defaults
import os.log

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

    var engineValue: InputMethod {
        switch self {
        case .telex:
            return .telex
        case .vni:
            return .vni
        case .simpleTelex:
            return .simpleTelex1
        }
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
    static let vietnameseSpellCheck = Key<Bool>("macUtils.vietnamese.spellCheck", default: true)
    static let vietnameseQuickTelex = Key<Bool>("macUtils.vietnamese.quickTelex", default: false)
}

/// Vietnamese typing through a session event tap: each key goes to the xkey engine, and when the
/// engine rewrites the word we swallow the key and send backspaces plus the new text.
final class VietnameseInput {
    static let shared = VietnameseInput()

    private static let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "VietnameseInput")

    private let session: InputSession
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var observations: [Defaults.Observation] = []
    private var workspaceObserver: NSObjectProtocol?
    private var toggleDetector = ModifierToggleDetector()
    private let injector = VietnameseInjector()

    private init() {
        session = InputSession(preferences: Self.runtimePreferences()) { nil }
    }

    var isRunning: Bool {
        tap != nil
    }

    func start() {
        observeSettings()
        updateTap()
    }

    func stop() {
        observations.forEach { $0.invalidate() }
        observations.removeAll()
        removeTap()
    }

    private func updateTap() {
        if Defaults[.vietnameseModuleEnabled] {
            installTap()
        } else {
            removeTap()
        }
    }

    private func installTap() {
        guard tap == nil else {
            return
        }

        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)
            | (1 << CGEventType.otherMouseDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { proxy, type, event, _ in
                // A C callback cannot capture dynamic Self.
                // swiftlint:disable:next prefer_self_in_static_references
                VietnameseInput.shared.handle(proxy: proxy, type: type, event: event)
            },
            userInfo: nil
        ) else {
            os_log("Cannot create keyboard event tap", log: Self.log, type: .error)
            return
        }

        self.tap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.injector.frontmostBundleID = app?.bundleIdentifier
            self?.resetForFocusChange()
        }
        injector.frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        applySettings()
    }

    private func removeTap() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
        }
        workspaceObserver = nil
        toggleDetector.reset()
        session.reset()
    }

    func toggleTyping() {
        Defaults[.vietnameseTypingOn].toggle()
    }

    // MARK: - Settings

    private static func runtimePreferences() -> RuntimePreferences {
        var preferences = Preferences()
        preferences.inputMethod = Defaults[.vietnameseInputMethod].engineValue
        preferences.codeTable = .unicode
        preferences.modernStyle = Defaults[.vietnameseModernStyle]
        preferences.spellCheckEnabled = Defaults[.vietnameseSpellCheck]
        preferences.restoreIfWrongSpelling = Defaults[.vietnameseSpellCheck]
        preferences.quickTelexEnabled = Defaults[.vietnameseQuickTelex]
        preferences.macroEnabled = false
        preferences.smartSwitchEnabled = false
        preferences.upperCaseFirstChar = false
        return RuntimePreferences(
            preferences: preferences,
            vietnameseEnabled: Defaults[.vietnameseTypingOn],
            windowTitleRulesEnabled: false,
            remoteDesktopInjectMode: false
        )
    }

    private func applySettings() {
        session.apply(Self.runtimePreferences())
    }

    private func observeSettings() {
        guard observations.isEmpty else {
            return
        }
        observations.append(Defaults.observe(
            keys: .vietnameseTypingOn,
            .vietnameseInputMethod,
            .vietnameseModernStyle,
            .vietnameseSpellCheck,
            .vietnameseQuickTelex,
            options: []
        ) { [weak self] in
            DispatchQueue.main.async {
                self?.applySettings()
            }
        })
        observations.append(Defaults.observe(.vietnameseModuleEnabled, options: []) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateTap()
            }
        })
    }

    // MARK: - Event handling

    private func resetForFocusChange() {
        _ = session.handle(InputEvent(
            kind: .focusChanged,
            keyCode: nil,
            characters: nil,
            modifiers: [],
            isRepeat: false
        ))
    }

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // Keys typed while the tap was off never reached the engine: its buffer no longer matches the screen.
            session.reset()
            toggleDetector.reset()
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            toggleDetector.cancel(flags: event.flags)
            resetForFocusChange()
            return Unmanaged.passUnretained(event)
        case .flagsChanged:
            handleToggleShortcut(event)
            return Unmanaged.passUnretained(event)
        case .keyDown:
            toggleDetector.cancel(flags: event.flags)
            return handleKeyDown(proxy: proxy, event: event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func handleToggleShortcut(_ event: CGEvent) {
        if toggleDetector.flagsChanged(event.flags) {
            DispatchQueue.main.async {
                self.toggleTyping()
            }
        }
    }

    private func handleKeyDown(proxy: CGEventTapProxy, event: CGEvent) -> Unmanaged<CGEvent>? {
        if event.getIntegerValueField(.eventSourceUserData) == VietnameseInjector.marker {
            return Unmanaged.passUnretained(event)
        }

        let inputEvent = InputEvent(
            kind: .keyDown,
            keyCode: UInt16(event.getIntegerValueField(.keyboardEventKeycode)),
            characters: Self.characters(of: event),
            modifiers: Self.modifiers(of: event),
            isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        )

        switch session.handle(inputEvent) {
        case .passThrough, .commit, .reset:
            return Unmanaged.passUnretained(event)
        case .consume:
            return nil
        case let .replacement(replacement):
            injector.inject(backspaces: replacement.backspaces, text: replacement.text, proxy: proxy)
            return nil
        }
    }

    private static func characters(of event: CGEvent) -> String? {
        var length = 0
        var buffer = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(
            maxStringLength: buffer.count,
            actualStringLength: &length,
            unicodeString: &buffer
        )
        guard length > 0 else {
            return nil
        }
        return String(utf16CodeUnits: buffer, count: length)
    }

    private static func modifiers(of event: CGEvent) -> InputModifiers {
        let flags = event.flags
        var modifiers: InputModifiers = []
        if flags.contains(.maskControl) {
            modifiers.insert(.control)
        }
        if flags.contains(.maskAlternate) {
            modifiers.insert(.option)
        }
        if flags.contains(.maskShift) {
            modifiers.insert(.shift)
        }
        if flags.contains(.maskCommand) {
            modifiers.insert(.command)
        }
        if flags.contains(.maskSecondaryFn) {
            modifiers.insert(.function)
        }
        if flags.contains(.maskAlphaShift) {
            modifiers.insert(.capsLock)
        }
        return modifiers
    }
}

/// ⌃⇧ pressed and released with no other key in between, like Unikey.
struct ModifierToggleDetector {
    private static let relevant: CGEventFlags = [.maskControl, .maskShift, .maskAlternate, .maskCommand]

    private var armed = false
    /// Set once the current modifier gesture is used for anything else; cleared only when every modifier is up.
    private var rejected = false

    /// Returns true when the shortcut completes (all modifiers released).
    mutating func flagsChanged(_ flags: CGEventFlags) -> Bool {
        let modifiers = flags.intersection(Self.relevant)
        if modifiers.isEmpty {
            let fire = armed && !rejected
            reset()
            return fire
        }
        if !modifiers.isSubset(of: [.maskControl, .maskShift]) {
            rejected = true
        } else if modifiers == [.maskControl, .maskShift] {
            armed = true
        }
        return false
    }

    /// A key or click happened; `flags` are the modifiers held at that moment.
    mutating func cancel(flags: CGEventFlags) {
        if !flags.intersection(Self.relevant).isEmpty {
            rejected = true
        }
        armed = false
    }

    mutating func reset() {
        armed = false
        rejected = false
    }
}
