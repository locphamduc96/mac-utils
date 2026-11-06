// MIT License
// Copyright (c) 2026 MacUtils

import Carbon
import Foundation

/// Selects the "MacUtils Tiếng Việt" input source (installed by Scripts/install-input-method) or a plain keyboard
/// layout through Text Input Sources.
enum VietnameseInputSource {
    static let sourceID = "com.rhodo.inputmethod.MacUtils"

    static var bundleURL: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Input Methods/MacUtilsVietnamese.app")
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: bundleURL.path)
    }

    static var isSelected: Bool {
        guard let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return false
        }
        return identifier(of: current) == sourceID
    }

    /// Enables and selects the MacUtils input source; false if it is not installed or macOS refuses.
    @discardableResult
    static func selectInputMethod() -> Bool {
        guard isInstalled else {
            return false
        }
        var source = find()
        if source == nil {
            TISRegisterInputSource(bundleURL as CFURL)
            source = find()
        }
        guard let source else {
            return false
        }
        TISEnableInputSource(source)
        return TISSelectInputSource(source) == noErr
    }

    /// Switches back to the user's ASCII keyboard layout (ABC / U.S.) when the MacUtils input source is selected.
    static func selectKeyboardLayout() {
        guard isSelected, let layout = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue()
        else {
            return
        }
        TISSelectInputSource(layout)
    }

    private static func find() -> TISInputSource? {
        let filter = [kTISPropertyInputSourceID as String: sourceID] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource] else {
            return nil
        }
        return list.first
    }

    private static func identifier(of source: TISInputSource) -> String? {
        guard let pointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
            return nil
        }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }
}
