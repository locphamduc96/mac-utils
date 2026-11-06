// MIT License
// Copyright (c) 2026 MacUtils

import AppKit
import ApplicationServices
import os.log

enum WindowMover {
    private static let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "WindowMover")

    static func perform(_ action: WindowLayoutAction) {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return
        }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        guard let window = copyElement(appElement, kAXFocusedWindowAttribute),
              let axFrame = frame(of: window),
              let primaryScreen = NSScreen.screens.first
        else {
            os_log("No focused window for %{public}@", log: log, type: .info, app.bundleIdentifier ?? "?")
            return
        }

        let primaryMaxY = primaryScreen.frame.maxY
        let windowFrame = WindowLayout.flipped(axFrame, primaryScreenMaxY: primaryMaxY)
        let screens = NSScreen.screens
        let screen = WindowLayout.screenIndex(for: windowFrame, screenFrames: screens.map(\.frame))
            .map { screens[$0] } ?? NSScreen.main ?? primaryScreen

        let target = WindowLayout.frame(for: action, in: screen.visibleFrame)
        setFrame(WindowLayout.flipped(target, primaryScreenMaxY: primaryMaxY), of: window, app: appElement)
    }

    private static func copyElement(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID()
        else {
            return nil
        }
        return (value as! AXUIElement)
    }

    private static func frame(of window: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success
        else {
            return nil
        }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        else {
            return nil
        }
        return CGRect(origin: position, size: size)
    }

    /// Size, then position, then size again: a window moving to another screen may first be clamped
    /// by the old screen's bounds (same order Rectangle uses).
    private static func setFrame(_ frame: CGRect, of window: AXUIElement, app: AXUIElement) {
        // AXEnhancedUserInterface (set by some assistive apps) animates and drops AX frame changes.
        let enhancedUI = "AXEnhancedUserInterface" as CFString
        var enhancedValue: CFTypeRef?
        let wasEnhanced = AXUIElementCopyAttributeValue(app, enhancedUI, &enhancedValue) == .success
            && (enhancedValue as? Bool) == true
        if wasEnhanced {
            AXUIElementSetAttributeValue(app, enhancedUI, kCFBooleanFalse)
        }
        defer {
            if wasEnhanced {
                AXUIElementSetAttributeValue(app, enhancedUI, kCFBooleanTrue)
            }
        }

        var size = frame.size
        var origin = frame.origin
        guard let sizeValue = AXValueCreate(.cgSize, &size),
              let originValue = AXValueCreate(.cgPoint, &origin)
        else {
            return
        }
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, originValue)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
    }
}
