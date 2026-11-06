// MIT License
// Copyright (c) 2026 MacUtils

import Carbon.HIToolbox
@testable import LinearMouse
import XCTest

final class VietnameseInputTests: XCTestCase {
    /// Replays keystrokes through the engine the way the event tap does and returns the resulting
    /// text field content. "<" stands for backspace.
    private func type(
        _ keys: String,
        method: InputMethod = .telex,
        spellCheck: Bool = true,
        modernStyle: Bool = false,
        vietnamese: Bool = true
    ) -> String {
        var preferences = Preferences()
        preferences.inputMethod = method
        preferences.spellCheckEnabled = spellCheck
        preferences.restoreIfWrongSpelling = spellCheck
        preferences.modernStyle = modernStyle
        preferences.quickTelexEnabled = false
        let session = InputSession(
            preferences: RuntimePreferences(
                preferences: preferences,
                vietnameseEnabled: vietnamese,
                windowTitleRulesEnabled: false,
                remoteDesktopInjectMode: false
            )
        ) { nil }

        var screen = ""
        for key in keys {
            let isBackspace = key == "<"
            let keyCode = isBackspace
                ? UInt16(kVK_Delete)
                : KeyCodeToCharacter.keyCode(forCharacter: Character(key.lowercased())) ?? 0
            let event = InputEvent(
                kind: .keyDown,
                keyCode: keyCode,
                characters: isBackspace ? nil : String(key),
                modifiers: key.isUppercase ? [.shift] : [],
                isRepeat: false
            )
            switch session.handle(event) {
            case .passThrough, .reset, .commit:
                if isBackspace {
                    if !screen.isEmpty {
                        screen.removeLast()
                    }
                } else {
                    screen.append(key)
                }
            case .consume:
                break
            case let .replacement(replacement):
                screen.removeLast(min(replacement.backspaces, screen.count))
                screen += replacement.text
            }
        }
        return screen
    }

    func testTelex() {
        XCTAssertEqual(type("tieengs vieetj "), "tiếng việt ")
        XCTAssertEqual(type("nguwowif ddaayj "), "người đậy ")
        XCTAssertEqual(type("nguyeenx "), "nguyễn ")
        XCTAssertEqual(type("Hoaf "), "Hòa ")
    }

    func testVNI() {
        XCTAssertEqual(type("tie61ng vie65t ", method: .vni), "tiếng việt ")
        XCTAssertEqual(type("d9a5y ", method: .vni), "đạy ")
    }

    func testModernStylePlacesToneOnSecondVowel() {
        XCTAssertEqual(type("Hoaf thuyr ", modernStyle: true), "Hoà thuỷ ")
        XCTAssertEqual(type("Hoaf thuyr ", modernStyle: false), "Hòa thủy ")
    }

    func testSpellCheckRestoresEnglishWords() {
        XCTAssertEqual(type("return "), "return ")
        XCTAssertEqual(type("return ", spellCheck: false), "retủn ")
    }

    func testRepeatedToneKeyUndoesTone() {
        XCTAssertEqual(type("ass "), "as ")
    }

    func testBackspaceKeepsEngineInSync() {
        XCTAssertEqual(type("vieetj<<eetj "), "việt ")
    }

    func testEnglishModePassesThrough() {
        XCTAssertEqual(type("tieengs vieetj ", vietnamese: false), "tieengs vieetj ")
    }

    func testToggleDetectorFiresOnCleanControlShiftRelease() {
        var detector = ModifierToggleDetector()
        XCTAssertFalse(detector.flagsChanged(.maskControl))
        XCTAssertFalse(detector.flagsChanged([.maskControl, .maskShift]))
        XCTAssertFalse(detector.flagsChanged(.maskShift))
        XCTAssertTrue(detector.flagsChanged([]))
    }

    func testToggleDetectorIgnoresShortcutsWithOtherKeys() {
        var detector = ModifierToggleDetector()
        XCTAssertFalse(detector.flagsChanged([.maskControl, .maskShift]))
        detector.cancel(flags: [.maskControl, .maskShift]) // ⌃⇧Tab
        XCTAssertFalse(detector.flagsChanged(.maskShift))
        XCTAssertFalse(detector.flagsChanged([]))

        XCTAssertFalse(detector.flagsChanged([.maskControl, .maskShift]))
        XCTAssertFalse(detector.flagsChanged([.maskControl, .maskShift, .maskCommand]))
        XCTAssertFalse(detector.flagsChanged([]))

        XCTAssertFalse(detector.flagsChanged(.maskShift))
        XCTAssertFalse(detector.flagsChanged([]))
    }

    func testToggleDetectorStaysRejectedWhenExtraModifierIsReleasedFirst() {
        var detector = ModifierToggleDetector()
        XCTAssertFalse(detector.flagsChanged([.maskControl, .maskShift, .maskCommand]))
        detector.cancel(flags: [.maskControl, .maskShift, .maskCommand]) // ⌃⇧⌘ + key
        XCTAssertFalse(detector.flagsChanged([.maskControl, .maskShift])) // ⌘ released first
        XCTAssertFalse(detector.flagsChanged([]))
    }

    func testToggleDetectorIgnoresPlainTypingBeforeShortcut() {
        var detector = ModifierToggleDetector()
        detector.cancel(flags: []) // a plain key with nothing held must not block the next gesture
        XCTAssertFalse(detector.flagsChanged(.maskControl))
        XCTAssertFalse(detector.flagsChanged([.maskControl, .maskShift]))
        XCTAssertTrue(detector.flagsChanged([]))
    }
}
