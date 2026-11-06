// MIT License
// Copyright (c) 2026 MacUtils

import Carbon.HIToolbox
import os.log

struct HotKeyCombo: Equatable {
    let keyCode: UInt32
    let carbonModifiers: UInt32
    let display: String

    static let controlOptionC = Self(
        keyCode: UInt32(kVK_ANSI_C),
        carbonModifiers: UInt32(controlKey | optionKey),
        display: "⌃⌥C"
    )
    static let controlOptionX = Self(
        keyCode: UInt32(kVK_ANSI_X),
        carbonModifiers: UInt32(controlKey | optionKey),
        display: "⌃⌥X"
    )
}

/// System-wide shortcuts through Carbon `RegisterEventHotKey`, which needs no extra permission.
final class GlobalHotKeys {
    static let shared = GlobalHotKeys()

    private static let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "GlobalHotKeys")
    fileprivate static let signature: OSType = 0x4D55_484B // "MUHK"

    private var eventHandler: EventHandlerRef?
    private var registered: [UInt32: (ref: EventHotKeyRef, action: () -> Void)] = [:]
    private var nextID: UInt32 = 1

    /// Combos another app already owns, so registration failed.
    private(set) var failedCombos: [String] = []

    @discardableResult
    func register(_ combo: HotKeyCombo, action: @escaping () -> Void) -> Bool {
        installHandlerIfNeeded()

        let id = nextID
        nextID += 1
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            combo.keyCode,
            combo.carbonModifiers,
            EventHotKeyID(signature: Self.signature, id: id),
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else {
            os_log("Cannot register %{public}@: %d", log: Self.log, type: .error, combo.display, status)
            failedCombos.append(combo.display)
            return false
        }
        registered[id] = (ref, action)
        return true
    }

    func unregisterAll() {
        for entry in registered.values {
            UnregisterEventHotKey(entry.ref)
        }
        registered.removeAll()
        failedCombos.removeAll()
    }

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else {
            return
        }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), hotKeyHandler, 1, &eventType, nil, &eventHandler)
    }

    fileprivate func handle(_ hotKeyID: EventHotKeyID) -> OSStatus {
        guard hotKeyID.signature == Self.signature, let entry = registered[hotKeyID.id] else {
            return OSStatus(eventNotHandledErr)
        }
        entry.action()
        return noErr
    }
}

private func hotKeyHandler(_: EventHandlerCallRef?, _ event: EventRef?, _: UnsafeMutableRawPointer?) -> OSStatus {
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else {
        return status
    }
    return GlobalHotKeys.shared.handle(hotKeyID)
}
