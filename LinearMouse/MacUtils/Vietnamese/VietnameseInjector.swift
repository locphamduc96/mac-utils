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

    /// Terminals apply a burst of synthetic backspaces and text out of order (letters swapped or lost),
    /// so they get xkey's paced sequence instead. List from xkey's `AppBehaviorDetector.terminalApps`.
    static let terminalBundleIDs: Set<String> = [
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
        "com.cmuxterm.app"
    ]

    /// xkey's terminal timings in microseconds.
    private enum TerminalDelay {
        static let backspace: UInt32 = 8000
        static let beforeText: UInt32 = 25_000
        static let text: UInt32 = 8000
        static let settle: UInt32 = 20_000
    }

    var frontmostBundleID: String?

    /// Entered while paced injections are queued or running, so the next physical key waits for them. The serial
    /// queue keeps injections in order; nothing on the tap thread ever waits without a timeout.
    private let pendingInjections = DispatchGroup()
    private let pacedQueue = DispatchQueue(label: "com.rhodo.MacUtils.vietnamese-injection", qos: .userInteractive)

    /// Call before handling a physical event: it must not overtake a paced injection still in flight. Bounded below
    /// the event-tap timeout; only a very long paced macro can outlast it.
    func waitForPendingInjection() {
        _ = pendingInjections.wait(timeout: .now() + .milliseconds(700))
    }

    /// Deletes `backspaces` characters and types `text`; `key` (Return / Tab) is sent again afterwards.
    /// `pacing` multiplies the terminal delays; nil sends everything at once.
    func inject(backspaces: Int, text: String, followedBy key: CGEvent?, pacing: UInt32?, proxy: CGEventTapProxy) {
        key?.setIntegerValueField(.eventSourceUserData, value: Self.marker)
        var backspaceCount = backspaces
        if backspaces > 0, let bundleID = frontmostBundleID, Self.inlineCompletionBundleIDs.contains(bundleID),
           Self.focusedSelectionLength() > 0 {
            backspaceCount += 1
        }
        if let pacing {
            injectPaced(backspaces: backspaceCount, text: text, followedBy: key, pacing: pacing)
            return
        }

        let source = CGEventSource(stateID: .privateState)
        for _ in 0 ..< backspaceCount {
            postKey(CGKeyCode(kVK_Delete), source: source, route: .proxy(proxy))
        }
        if !text.isEmpty {
            postText(text, source: source, route: .proxy(proxy))
        }
        key?.tapPostEvent(proxy)
    }

    /// Posts below every event tap (annotated session) off the tap callback, with xkey's terminal delays.
    /// The group is entered before dispatch so a key typed meanwhile cannot slip in first.
    private func injectPaced(backspaces: Int, text: String, followedBy key: CGEvent?, pacing: UInt32) {
        pendingInjections.enter()
        pacedQueue.async { [pendingInjections] in
            defer { pendingInjections.leave() }
            let source = CGEventSource(stateID: .privateState)
            for _ in 0 ..< backspaces {
                self.postKey(CGKeyCode(kVK_Delete), source: source, route: .session)
                usleep(TerminalDelay.backspace * pacing)
            }
            if backspaces > 0 {
                usleep(TerminalDelay.beforeText * pacing)
            }
            if !text.isEmpty {
                self.postText(text, source: source, route: .session, delay: TerminalDelay.text * pacing)
            }
            if let key {
                usleep(TerminalDelay.text * pacing)
                key.post(tap: .cgAnnotatedSessionEventTap)
            }
            usleep(TerminalDelay.settle * pacing)
        }
    }

    private enum Route {
        case proxy(CGEventTapProxy)
        case session
    }

    private func postKey(_ keyCode: CGKeyCode, source: CGEventSource?, route: Route) {
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else {
            return
        }
        post(down, up, route: route)
    }

    /// Unicode events carry at most 20 UTF-16 units each.
    private func postText(_ text: String, source: CGEventSource?, route: Route, delay: UInt32 = 0) {
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
            post(down, up, route: route)
            offset = end
            if delay > 0, offset < units.count {
                usleep(delay)
            }
        }
    }

    private func post(_ down: CGEvent, _ up: CGEvent, route: Route) {
        // Without clearing, a held Shift (capital letter) would turn the backspace into ⇧⌫.
        down.flags = []
        up.flags = []
        down.setIntegerValueField(.eventSourceUserData, value: Self.marker)
        up.setIntegerValueField(.eventSourceUserData, value: Self.marker)
        switch route {
        case let .proxy(proxy):
            down.tapPostEvent(proxy)
            up.tapPostEvent(proxy)
        case .session:
            // Downstream of our tap whether it sits at HID or (fallback) session level.
            down.post(tap: .cgAnnotatedSessionEventTap)
            up.post(tap: .cgAnnotatedSessionEventTap)
        }
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
