// MIT License
// Copyright (c) 2026 MacUtils
// Injection approach follows xkey's CharacterInjector (https://github.com/xmannv/xkey), MIT License.

import ApplicationServices
import Carbon.HIToolbox
import CoreGraphics

final class VietnameseInjector {
    /// Tags our synthetic events so the tap lets them through untouched ("MUVN").
    static let marker: Int64 = 0x4D55_564E

    /// Apps whose fields auto-select an inline completion after the caret (address bars, Spotlight).
    /// There a backspace first removes the selected suggestion, so one more is needed.
    static let inlineCompletionBundleIDs: Set<String> = [
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
        "com.apple.Spotlight",
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "company.thebrowser.Browser",
        "com.vivaldi.Vivaldi",
        "com.operasoftware.Opera",
        "org.mozilla.firefox",
        "org.mozilla.firefoxdeveloperedition",
        "app.zen-browser.zen",
        "com.coccoc.Coccoc"
    ]

    var frontmostBundleID: String?

    func inject(backspaces: Int, text: String, proxy: CGEventTapProxy) {
        let source = CGEventSource(stateID: .privateState)
        var backspaceCount = backspaces

        if backspaces > 0, let bundleID = frontmostBundleID, Self.inlineCompletionBundleIDs.contains(bundleID),
           Self.focusedSelectionLength() > 0 {
            backspaceCount += 1
        }
        for _ in 0 ..< backspaceCount {
            postKey(CGKeyCode(kVK_Delete), source: source, proxy: proxy)
        }
        if !text.isEmpty {
            postText(text, source: source, proxy: proxy)
        }
    }

    private func postKey(_ keyCode: CGKeyCode, source: CGEventSource?, proxy: CGEventTapProxy) {
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else {
            return
        }
        post(down, up, proxy: proxy)
    }

    /// Unicode events carry at most 20 UTF-16 units each.
    private func postText(_ text: String, source: CGEventSource?, proxy: CGEventTapProxy) {
        let units = Array(text.utf16)
        var offset = 0
        while offset < units.count {
            let end = min(offset + 20, units.count)
            var chunk = Array(units[offset ..< end])
            guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            else {
                return
            }
            down.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: &chunk)
            up.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: &chunk)
            post(down, up, proxy: proxy)
            offset = end
        }
    }

    private func post(_ down: CGEvent, _ up: CGEvent, proxy: CGEventTapProxy) {
        // Without clearing, a held Shift (capital letter) would turn the backspace into ⇧⌫.
        down.flags = []
        up.flags = []
        down.setIntegerValueField(.eventSourceUserData, value: Self.marker)
        up.setIntegerValueField(.eventSourceUserData, value: Self.marker)
        down.tapPostEvent(proxy)
        up.tapPostEvent(proxy)
    }

    /// Length of the selection in the focused text field, 0 when there is none or AX cannot tell.
    private static func focusedSelectionLength() -> Int {
        let systemWide = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID()
        else {
            return 0
        }
        var rangeValue: CFTypeRef?
        // swiftlint:disable:next force_cast
        let element = focused as! AXUIElement
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue) ==
            .success,
            let rangeValue, CFGetTypeID(rangeValue) == AXValueGetTypeID()
        else {
            return 0
        }
        var range = CFRange()
        // swiftlint:disable:next force_cast
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &range) else {
            return 0
        }
        return max(range.length, 0)
    }
}
