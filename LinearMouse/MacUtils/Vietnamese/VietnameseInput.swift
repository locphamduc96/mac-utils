// MIT License
// Copyright (c) 2026 MacUtils

import AppKit
import Carbon.HIToolbox
import Defaults
import os.log

/// Vietnamese typing through a keyboard event tap: each key goes to `VietTypingEngine`, and when the
/// engine rewrites the word we swallow the key and send backspaces plus the new text.
final class VietnameseInput {
    static let shared = VietnameseInput()

    private static let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "VietnameseInput")

    private let engine = VietTypingEngine()
    private let injector = VietnameseInjector()
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var observations: [Defaults.Observation] = []
    private var workspaceObserver: NSObjectProtocol?
    private var toggleDetector = ModifierToggleDetector()
    private var frontmostBundleID: String?
    private var mapRules: [String: VietnameseAppRule] = [:]
    private var inputSourceObserver: NSObjectProtocol?
    /// False while an input method is selected (the MacUtils input source, Japanese, Korean…): it handles keys itself.
    private var keyboardLayoutActive = true

    private init() {}

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

    func toggleTyping() {
        Defaults[.vietnameseTypingOn].toggle()
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
        // HID level, like xkey: paced terminal injections post to the session tap, below this tap, so a
        // key held back here (waitForPendingInjection) always lands after them. Session level is the fallback.
        let createTap = { (location: CGEventTapLocation) in
            CGEvent.tapCreate(
                tap: location,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: CGEventMask(mask),
                callback: { proxy, type, event, _ in
                    // A C callback cannot capture dynamic Self.
                    // swiftlint:disable:next prefer_self_in_static_references
                    VietnameseInput.shared.handle(proxy: proxy, type: type, event: event)
                },
                userInfo: nil
            )
        }
        guard let tap = createTap(.cghidEventTap) ?? createTap(.cgSessionEventTap) else {
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
            self?.frontmostApplicationChanged(to: app?.bundleIdentifier)
        }
        frontmostApplicationChanged(to: NSWorkspace.shared.frontmostApplication?.bundleIdentifier)

        inputSourceObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateInputSourceState()
        }
        updateInputSourceState()
        applySettings()
    }

    private func updateInputSourceState() {
        engine.reset()
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceType)
        else {
            keyboardLayoutActive = true
            return
        }
        let type = Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue()
        keyboardLayoutActive = CFEqual(type, kTISTypeKeyboardLayout)
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
        if let inputSourceObserver {
            DistributedNotificationCenter.default().removeObserver(inputSourceObserver)
        }
        inputSourceObserver = nil
        toggleDetector.reset()
        engine.reset()
    }

    // MARK: - Settings

    private func applySettings() {
        var settings = VietTypingSettings()
        settings.method = Defaults[.vietnameseInputMethod].engineValue
        settings.modernStyle = Defaults[.vietnameseModernStyle]
        settings.restoreEnglish = Defaults[.vietnameseRestoreEnglish]
        settings.codeTable = Defaults[.vietnameseCodeTable]
        if Defaults[.vietnameseMacrosEnabled] {
            var mapMacros: [String: String] = [:]
            for macro in Defaults[.vietnameseMacros] where !macro.shortcut.isEmpty {
                mapMacros[macro.shortcut.lowercased()] = macro.expansion
            }
            settings.macros = mapMacros
        }
        engine.settings = settings
        engine.reset()
        mapRules = Dictionary(Defaults[.vietnameseAppRules].map { ($0.bundleID, $0) }) { first, _ in first }
    }

    private func observeSettings() {
        guard observations.isEmpty else {
            return
        }
        observations.append(Defaults.observe(
            keys: .vietnameseInputMethod,
            .vietnameseModernStyle,
            .vietnameseRestoreEnglish,
            .vietnameseCodeTable,
            .vietnameseMacrosEnabled,
            .vietnameseMacros,
            .vietnameseAppRules,
            options: []
        ) { [weak self] in
            DispatchQueue.main.async {
                self?.applySettings()
            }
        })
        observations.append(Defaults.observe(.vietnameseTypingOn, options: []) { [weak self] change in
            DispatchQueue.main.async {
                self?.engine.reset()
                self?.rememberTypingState(change.newValue)
            }
        })
        observations.append(Defaults.observe(.vietnameseModuleEnabled, options: []) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateTap()
            }
        })
    }

    // MARK: - Per-app state

    private func frontmostApplicationChanged(to bundleID: String?) {
        // Remember the app being left too, so a first visit's state is kept when coming back.
        rememberTypingState(Defaults[.vietnameseTypingOn])
        frontmostBundleID = bundleID
        injector.frontmostBundleID = bundleID
        engine.reset()
        guard Defaults[.vietnameseRememberPerApp], let bundleID, bundleID != Bundle.main.bundleIdentifier,
              let stored = Defaults[.vietnamesePerAppTyping][bundleID], stored != Defaults[.vietnameseTypingOn]
        else {
            return
        }
        Defaults[.vietnameseTypingOn] = stored
    }

    private func rememberTypingState(_ typingOn: Bool) {
        guard Defaults[.vietnameseRememberPerApp], let bundleID = frontmostBundleID,
              bundleID != Bundle.main.bundleIdentifier
        else {
            return
        }
        Defaults[.vietnamesePerAppTyping][bundleID] = typingOn
    }

    private var isExcludedApp: Bool {
        frontmostBundleID.flatMap { mapRules[$0]?.excluded } ?? false
    }

    /// Delay multiplier for the frontmost app, or nil to inject immediately.
    private var injectionPacing: UInt32? {
        guard let bundleID = frontmostBundleID else {
            return nil
        }
        let mode = mapRules[bundleID]?.injection ?? .auto
        if mode == .auto, !VietnameseInjector.terminalBundleIDs.contains(bundleID) {
            return nil
        }
        return mode.pacing
    }

    // MARK: - Event handling

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // Keys typed while the tap was off never reached the engine: its word no longer matches the screen.
            engine.reset()
            toggleDetector.reset()
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            injector.waitForPendingInjection()
            toggleDetector.cancel(flags: event.flags)
            engine.reset()
            return Unmanaged.passUnretained(event)
        case .flagsChanged:
            if Defaults[.vietnameseToggleHotkey] == .controlShift, toggleDetector.flagsChanged(event.flags) {
                DispatchQueue.main.async {
                    self.toggleTyping()
                }
            }
            return Unmanaged.passUnretained(event)
        case .keyDown:
            toggleDetector.cancel(flags: event.flags)
            return handleKeyDown(proxy: proxy, event: event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func handleKeyDown(proxy: CGEventTapProxy, event: CGEvent) -> Unmanaged<CGEvent>? {
        if event.getIntegerValueField(.eventSourceUserData) == VietnameseInjector.marker {
            return Unmanaged.passUnretained(event)
        }
        injector.waitForPendingInjection()

        if isToggleShortcut(event) {
            engine.reset()
            DispatchQueue.main.async {
                self.toggleTyping()
            }
            return nil
        }
        guard Defaults[.vietnameseTypingOn], keyboardLayoutActive, !isExcludedApp else {
            engine.reset()
            return Unmanaged.passUnretained(event)
        }

        switch engine.process(Self.vietKey(for: event)) {
        case .pass:
            return Unmanaged.passUnretained(event)
        case let .replace(output, deliverKey):
            injector.inject(
                backspaces: output.backspaces,
                text: output.text,
                followedBy: deliverKey ? event.copy() : nil,
                pacing: injectionPacing,
                proxy: proxy
            )
            return nil
        }
    }

    private func isToggleShortcut(_ event: CGEvent) -> Bool {
        guard let shortcut = Defaults[.vietnameseToggleHotkey].keyShortcut else {
            return false
        }
        let modifiers = event.flags.intersection([.maskControl, .maskAlternate, .maskShift, .maskCommand])
        return event.getIntegerValueField(.keyboardEventKeycode) == shortcut.keyCode && modifiers == shortcut.flags
    }

    private static let caretKeyCodes: Set<Int> = [
        kVK_LeftArrow, kVK_RightArrow, kVK_UpArrow, kVK_DownArrow, kVK_Home, kVK_End, kVK_PageUp, kVK_PageDown,
        kVK_ForwardDelete
    ]

    static func vietKey(for event: CGEvent) -> VietKey {
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        if !flags.isDisjoint(with: [.maskCommand, .maskControl, .maskAlternate]) {
            return .reset
        }
        switch keyCode {
        case kVK_Delete:
            return .backspace
        case kVK_Escape:
            return .escape
        case kVK_Return, kVK_ANSI_KeypadEnter, kVK_Tab:
            return .commit
        case _ where caretKeyCodes.contains(keyCode):
            return .reset
        default:
            break
        }
        guard let text = characters(of: event), text.count == 1, let character = text.first else {
            return .reset
        }
        return .character(character)
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
        if !flags.isDisjoint(with: Self.relevant) {
            rejected = true
        }
        armed = false
    }

    mutating func reset() {
        armed = false
        rejected = false
    }
}
