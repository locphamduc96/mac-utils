// MIT License
// Copyright (c) 2026 MacUtils

import Carbon.HIToolbox
import Cocoa
import InputMethodKit

/// The input source flavour of the MacUtils Vietnamese typing: same engine, but the word being typed is
/// shown as marked (underlined) text and committed when it ends, so no synthetic backspaces are needed.
@objc(MacUtilsInputController)
final class MacUtilsInputController: IMKInputController {
    private let engine = VietTypingEngine()
    /// Marked text currently shown, in the output code table.
    private var marked = ""

    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        engine.isEnglishWord = EnglishDictionary.contains
        engine.settings = SharedSettings.load()
        engine.reset()
        marked = ""
    }

    override func deactivateServer(_ sender: Any!) {
        commit(sender)
        super.deactivateServer(sender)
    }

    override func commitComposition(_ sender: Any!) {
        commit(sender)
    }

    override func recognizedEvents(_: Any!) -> Int {
        Int(NSEvent.EventTypeMask.keyDown.rawValue)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, event.type == .keyDown, let client = sender as? IMKTextInput else {
            return false
        }
        // English mode (⌃⇧ in the app) or an "always English" app: type plain keys.
        guard SharedSettings.typingOn, !SharedSettings.isExcluded(bundleID: client.bundleIdentifier()) else {
            if !marked.isEmpty {
                insert(marked, in: client)
            }
            engine.reset()
            return false
        }
        let key = Self.vietKey(for: event)
        let typed = event.characters ?? ""
        let action = engine.process(key)
        let composing = !engine.displayed.isEmpty

        switch key {
        case .character:
            let text = apply(action, typed: typed)
            if composing {
                show(text, in: client)
            } else {
                insert(text, in: client)
            }
            return true
        case .backspace:
            guard !marked.isEmpty else {
                return false
            }
            let text = apply(action, typed: nil, deletesOne: true)
            show(composing ? text : "", in: client)
            return true
        case .escape:
            guard !marked.isEmpty else {
                return false
            }
            show(apply(action, typed: nil), in: client)
            return true
        case .commit:
            insert(apply(action, typed: nil), in: client)
            return false
        case .reset:
            insert(marked, in: client)
            return false
        }
    }

    /// Applies an engine edit to the marked text.
    private func apply(_ action: VietAction, typed: String?, deletesOne: Bool = false) -> String {
        var scalars = Array(marked.unicodeScalars)
        switch action {
        case .pass:
            if deletesOne {
                scalars.removeLast(min(1, scalars.count))
            } else if let typed {
                scalars.append(contentsOf: engine.settings.codeTable.encode(typed).unicodeScalars)
            }
        case let .replace(output, _):
            scalars.removeLast(min(output.backspaces, scalars.count))
            scalars.append(contentsOf: output.text.unicodeScalars)
        }
        var view = String.UnicodeScalarView()
        view.append(contentsOf: scalars)
        return String(view)
    }

    private func show(_ text: String, in client: IMKTextInput) {
        marked = text
        client.setMarkedText(
            text,
            selectionRange: NSRange(location: (text as NSString).length, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
        )
    }

    private func insert(_ text: String, in client: IMKTextInput) {
        marked = ""
        engine.reset()
        guard !text.isEmpty else {
            return
        }
        client.insertText(text, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
    }

    private func commit(_ sender: Any?) {
        guard let client = sender as? IMKTextInput, !marked.isEmpty else {
            engine.reset()
            marked = ""
            return
        }
        insert(marked, in: client)
    }

    private static func vietKey(for event: NSEvent) -> VietKey {
        if !event.modifierFlags.isDisjoint(with: [.command, .control, .option]) {
            return .reset
        }
        switch Int(event.keyCode) {
        case kVK_Delete:
            return .backspace
        case kVK_Escape:
            return .escape
        case kVK_Return, kVK_ANSI_KeypadEnter, kVK_Tab:
            return .commit
        case kVK_LeftArrow, kVK_RightArrow, kVK_UpArrow, kVK_DownArrow, kVK_Home, kVK_End, kVK_PageUp,
             kVK_PageDown, kVK_ForwardDelete:
            return .reset
        default:
            break
        }
        guard let text = event.characters, text.count == 1, let character = text.first else {
            return .reset
        }
        return .character(character)
    }
}

/// Reads the settings the MacUtils app writes (same keys as `VietnameseSettingsModel.swift`). Enums are stored as
/// plain raw values; arrays of structs as arrays of JSON strings.
enum SharedSettings {
    private static let defaults = UserDefaults(suiteName: "com.rhodo.MacUtils")

    /// Module switched on and Vietnamese (V) selected.
    static var typingOn: Bool {
        let moduleEnabled = defaults?.object(forKey: "macUtils.vietnamese.moduleEnabled") as? Bool ?? true
        return moduleEnabled && defaults?.object(forKey: "macUtils.vietnamese.typingOn") as? Bool ?? true
    }

    static func isExcluded(bundleID: String?) -> Bool {
        guard let bundleID, let listRules = defaults?.array(forKey: "macUtils.vietnamese.appRules") as? [String] else {
            return false
        }
        return listRules.contains { json in
            let object = jsonObject(json)
            return object["bundleID"] as? String == bundleID && object["excluded"] as? Bool == true
        }
    }

    /// Empty when the string is not a JSON object.
    private static func jsonObject(_ json: String) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any] ?? [:]
    }

    static func load() -> VietTypingSettings {
        var settings = VietTypingSettings()
        if let raw = defaults?.string(forKey: "macUtils.vietnamese.inputMethod"),
           let method = VietInputMethod(rawValue: raw) {
            settings.method = method
        }
        settings.modernStyle = defaults?.bool(forKey: "macUtils.vietnamese.modernStyle") ?? false
        settings.restoreEnglish = defaults?.object(forKey: "macUtils.vietnamese.restoreEnglish") as? Bool ?? true
        if let raw = defaults?.string(forKey: "macUtils.vietnamese.codeTable"),
           let table = VietCodeTable(rawValue: raw) {
            settings.codeTable = table
        }
        let macrosEnabled = defaults?.object(forKey: "macUtils.vietnamese.macrosEnabled") as? Bool ?? true
        if macrosEnabled, let listMacros = defaults?.array(forKey: "macUtils.vietnamese.macros") as? [String] {
            var mapMacros: [String: String] = [:]
            for json in listMacros {
                let object = jsonObject(json)
                guard let shortcut = object["shortcut"] as? String, !shortcut.isEmpty,
                      let expansion = object["expansion"] as? String
                else {
                    continue
                }
                mapMacros[shortcut.lowercased()] = expansion
            }
            settings.macros = mapMacros
        }
        return settings
    }
}
