// MIT License
// Copyright (c) 2026 MacUtils

import Carbon.HIToolbox
import Defaults
@testable import LinearMouse
import XCTest

final class VietnameseInputTests: XCTestCase {
    private func keyEvent(_ keyCode: Int, text: String? = nil, flags: CGEventFlags = []) -> CGEvent {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: true)!
        event.flags = flags
        if let text {
            var units = Array(text.utf16)
            event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
        }
        return event
    }

    func testKeyEventsMapToEngineKeys() {
        XCTAssertEqual(VietnameseInput.vietKey(for: keyEvent(kVK_ANSI_A, text: "a")), .character("a"))
        XCTAssertEqual(
            VietnameseInput.vietKey(for: keyEvent(kVK_ANSI_A, text: "A", flags: .maskShift)),
            .character("A")
        )
        XCTAssertEqual(VietnameseInput.vietKey(for: keyEvent(kVK_Space, text: " ")), .character(" "))
        XCTAssertEqual(VietnameseInput.vietKey(for: keyEvent(kVK_Delete)), .backspace)
        XCTAssertEqual(VietnameseInput.vietKey(for: keyEvent(kVK_Escape)), .escape)
        XCTAssertEqual(VietnameseInput.vietKey(for: keyEvent(kVK_Return)), .commit)
        XCTAssertEqual(VietnameseInput.vietKey(for: keyEvent(kVK_Tab)), .commit)
        XCTAssertEqual(VietnameseInput.vietKey(for: keyEvent(kVK_LeftArrow)), .reset)
        XCTAssertEqual(
            VietnameseInput.vietKey(for: keyEvent(kVK_ANSI_C, text: "c", flags: .maskCommand)),
            .reset
        )
    }

    /// The input method reads macros straight from UserDefaults as an array of JSON strings.
    func testMacrosAreStoredAsJSONStrings() throws {
        let suite = try XCTUnwrap(UserDefaults(suiteName: "MacUtilsTests.macros"))
        suite.removePersistentDomain(forName: "MacUtilsTests.macros")
        let key = Defaults.Key<[VietnameseMacro]>("macros", default: [], suite: suite)
        Defaults[key] = [VietnameseMacro(shortcut: "vn", expansion: "Việt Nam")]
        let stored = try XCTUnwrap(suite.array(forKey: "macros") as? [String])
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(stored[0].utf8)) as? [String: Any]
        )
        XCTAssertEqual(object["shortcut"] as? String, "vn")
        XCTAssertEqual(object["expansion"] as? String, "Việt Nam")
        suite.removePersistentDomain(forName: "MacUtilsTests.macros")
    }

    /// The input method reads these keys as plain strings and JSON-string arrays.
    func testSettingsAreStoredInTheFormatTheInputMethodReads() throws {
        let suite = try XCTUnwrap(UserDefaults(suiteName: "MacUtilsTests.settings"))
        suite.removePersistentDomain(forName: "MacUtilsTests.settings")
        Defaults[.init("method", default: VietnameseInputMethod.telex, suite: suite)] = .vni
        Defaults[.init("table", default: VietCodeTable.unicode, suite: suite)] = .vniWindows
        Defaults[.init("rules", default: [VietnameseAppRule](), suite: suite)] = [
            VietnameseAppRule(bundleID: "com.example", name: "Example", excluded: true)
        ]
        XCTAssertEqual(suite.string(forKey: "method"), "vni")
        XCTAssertEqual(suite.string(forKey: "table"), "vniWindows")
        let rule = try XCTUnwrap((suite.array(forKey: "rules") as? [String])?.first)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(rule.utf8)) as? [String: Any])
        XCTAssertEqual(object["bundleID"] as? String, "com.example")
        XCTAssertEqual(object["excluded"] as? Bool, true)
        suite.removePersistentDomain(forName: "MacUtilsTests.settings")
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
