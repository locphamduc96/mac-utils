// MIT License
// Copyright (c) 2026 MacUtils
// Synchronous proxy posting as in OpenKey / Mkey; pacing idea and terminal list from xkey
// (https://github.com/xmannv/xkey), MIT License.

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

    /// Apps that apply a burst of synthetic backspaces and text badly (letters swapped or lost) get short
    /// pauses between the events. Terminals from xkey's `AppBehaviorDetector.terminalApps`, plus Telegram.
    static let pacedBundleIDs: Set<String> = [
        "com.apple.Terminal",
        "io.alacritty",
        "com.mitchellh.ghostty",
        "net.kovidgoyal.kitty",
        "com.github.wez.wezterm",
        "com.raphaelamorim.rio",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "co.zeit.hyper",
        "org.tabby",
        "com.termius-dmg.mac",
        "com.cmuxterm.app",
        "ru.keepcoder.Telegram",
        "org.telegram.desktop"
    ]

    /// Pauses in microseconds at pacing 1, multiplied by the per-app level.
    private enum Pause {
        static let backspace: UInt32 = 3000
        static let beforeText: UInt32 = 8000
        static let text: UInt32 = 3000
        /// Keeps a slow app's tap callback well under the event-tap timeout.
        static let maximumTotal: UInt32 = 250_000
    }

    var frontmostBundleID: String?

    /// Deletes `backspaces` characters and types `text`; `key` (Return / Tab) is sent again afterwards.
    ///
    /// Everything is posted synchronously through the tap proxy, as OpenKey / Mkey do: the events enter the stream
    /// right where the swallowed key was, so a key typed afterwards always lands after them. `pacing` (nil = none)
    /// adds pauses between the events for apps that need them; they also run on the tap thread, keeping that order.
    func inject(backspaces: Int, text: String, followedBy key: CGEvent?, pacing: UInt32?, proxy: CGEventTapProxy) {
        key?.setIntegerValueField(.eventSourceUserData, value: Self.marker)
        var backspaceCount = backspaces
        if backspaces > 0, let bundleID = frontmostBundleID, Self.inlineCompletionBundleIDs.contains(bundleID),
           Self.focusedSelectionLength() > 0 {
            backspaceCount += 1
        }

        var budget = pacing == nil ? 0 : Pause.maximumTotal
        func pause(_ base: UInt32) {
            guard let pacing, budget > 0 else {
                return
            }
            let duration = min(base * pacing, budget)
            budget -= duration
            usleep(duration)
        }

        let source = CGEventSource(stateID: .privateState)
        for _ in 0 ..< backspaceCount {
            postKey(CGKeyCode(kVK_Delete), source: source, proxy: proxy)
            pause(Pause.backspace)
        }
        if backspaceCount > 0 {
            pause(Pause.beforeText)
        }
        if !text.isEmpty {
            postText(text, source: source, proxy: proxy) {
                pause(Pause.text)
            }
        }
        key?.tapPostEvent(proxy)
    }

    private func postKey(_ keyCode: CGKeyCode, source: CGEventSource?, proxy: CGEventTapProxy) {
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else {
            return
        }
        post(down, up, proxy: proxy)
    }

    /// Unicode events carry at most 20 UTF-16 units each; `between` runs between the events.
    private func postText(
        _ text: String,
        source: CGEventSource?,
        proxy: CGEventTapProxy,
        between: () -> Void
    ) {
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
            if offset < units.count {
                between()
            }
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
