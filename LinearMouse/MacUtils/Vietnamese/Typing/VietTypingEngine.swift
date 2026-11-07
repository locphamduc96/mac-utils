// MIT License
// Copyright (c) 2026 MacUtils

import Foundation

struct VietTypingSettings: Equatable {
    var method: VietInputMethod = .telex
    var modernStyle = false
    /// Show the typed keys again when a word cannot be Vietnamese ("source", "text", "user").
    var restoreEnglish = true
    var codeTable: VietCodeTable = .unicode
    /// Lowercased shortcut → expansion, applied when a word ends ("vn" → "Việt Nam").
    var macros: [String: String] = [:]
}

enum VietKey: Equatable {
    case character(Character)
    case backspace
    case escape
    /// Return / Tab: ends the word; the key itself still has to reach the app.
    case commit
    /// Arrow keys, clicks, shortcuts: the caret moved, forget the word.
    case reset
}

struct VietOutput: Equatable {
    var backspaces: Int
    var text: String
}

enum VietAction: Equatable {
    /// Let the key through unchanged.
    case pass
    /// Swallow the key, delete `backspaces` characters and type `text`; with `deliverKey` the key is
    /// sent again afterwards.
    case replace(VietOutput, deliverKey: Bool)
}

/// Turns keystrokes into edits of the text field. Pure logic: the event tap and the input method feed it
/// keys and apply the edits.
final class VietTypingEngine {
    var settings: VietTypingSettings

    /// Answers whether a word is English; used when a word whose modifier was cancelled ends ("message",
    /// typed m-e-s-s-a-g-e, shows "mesage" like Unikey until Space restores the keys). Nil: never restore those.
    var isEnglishWord: ((String) -> Bool)?

    private var word = VietWord()
    /// Keys exactly as typed.
    private var typed = ""
    /// The word as plain keys, with each cancelled modifier counted once ("tesst" → "test", "cass" → "cas").
    private var raw = ""
    /// A modifier was cancelled in this word.
    private var hadUndo = false
    /// `typed.count` right after the last cancelled modifier; keys after it appear in both `typed` and `raw`.
    private var typedCountAtLastUndo = 0
    /// Current word as the app shows it (Unicode).
    private(set) var displayed = ""
    /// The word is not Vietnamese: keys are shown as typed until it ends.
    private var showsRaw = false
    /// ESC asked for the typed keys: keep them even if the word becomes Vietnamese again.
    private var keepsRaw = false

    /// Common English words that are also valid Vietnamese syllables in Telex but rare as Vietnamese
    /// words; restored when the word ends. Words like "mix" (mĩ) or "sex" (sẽ) are left Vietnamese.
    static let englishWords: Set<String> = [
        "as", "is", "us", "if", "of", "or", "has", "his", "her", "was", "now", "how", "row", "see", "tree",
        "door", "keep", "deep", "soon", "test", "data", "var", "post", "most", "list", "does", "theme", "did",
        "dad", "queue", "these", "there", "here", "reset"
    ]

    init(settings: VietTypingSettings = VietTypingSettings()) {
        self.settings = settings
    }

    func reset() {
        word = VietWord()
        typed = ""
        raw = ""
        hadUndo = false
        typedCountAtLastUndo = 0
        displayed = ""
        showsRaw = false
        keepsRaw = false
    }

    func process(_ key: VietKey) -> VietAction {
        switch key {
        case let .character(character):
            return isWordCharacter(character) ? typeLetter(character) : endWord(with: character)
        case .backspace:
            return backspace()
        case .escape:
            return restoreTypedKeys()
        case .commit:
            let old = displayed
            let finished = finishedWord()
            reset()
            guard let finished, finished != old else {
                return .pass
            }
            return .replace(edit(from: old, to: finished), deliverKey: true)
        case .reset:
            reset()
            return .pass
        }
    }

    // MARK: - Keys

    private func isWordCharacter(_ character: Character) -> Bool {
        guard let ascii = character.asciiValue else {
            return false
        }
        if character.isLetter {
            return true
        }
        // VNI digits modify the word being typed; on their own they are just digits.
        return settings.method == .vni && ascii >= 48 && ascii <= 57 && !raw.isEmpty
    }

    private func typeLetter(_ character: Character) -> VietAction {
        let old = displayed
        typed.append(character)
        if showsRaw {
            raw.append(character)
        } else {
            word.type(character, method: settings.method)
            if word.didUndo {
                hadUndo = true
                typedCountAtLastUndo = typed.count
            } else {
                raw.append(character)
            }
            if settings.restoreEnglish, word.validity == .invalid {
                showsRaw = true
            }
        }
        displayed = showsRaw ? raw : word.rendered(modernStyle: settings.modernStyle)
        return action(from: old, to: displayed, typed: String(character))
    }

    private func endWord(with character: Character) -> VietAction {
        let old = displayed
        let finished = finishedWord()
        reset()
        guard let finished, finished != old else {
            return .pass
        }
        return .replace(edit(from: old, to: finished + String(character)), deliverKey: false)
    }

    /// What the word should become when it ends: a macro expansion, the typed keys, or nil to keep it.
    private func finishedWord() -> String? {
        guard !raw.isEmpty else {
            return nil
        }
        if let expansion = settings.macros[typed.lowercased()] {
            return typed.first?.isUppercase == true ? expansion.prefix(1).uppercased() + expansion
                .dropFirst() : expansion
        }
        guard settings.restoreEnglish else {
            return nil
        }
        // Like Unikey a cancelled modifier types itself once ("tesst" → "test"); real English words with doubled
        // letters get their keys back ("message", "issue", "pass").
        if hadUndo, typed != displayed, showsRaw || word.validity != .complete,
           isEnglishWord?(typed.lowercased()) == true {
            return typed
        }
        guard !showsRaw, displayed != raw else {
            return nil
        }
        if word.validity != .complete || Self.englishWords.contains(raw.lowercased()) {
            return raw
        }
        return nil
    }

    private func backspace() -> VietAction {
        guard !raw.isEmpty else {
            return .pass
        }
        if showsRaw {
            raw.removeLast()
            // A key typed after the last cancelled modifier sits at the end of both; otherwise the history is gone.
            if hadUndo, typed.count > typedCountAtLastUndo {
                typed.removeLast()
            } else {
                typed = raw
                hadUndo = false
            }
            displayed = raw
            if raw.isEmpty {
                reset()
            } else if !keepsRaw {
                resumeVietnameseIfPossible()
            }
            return .pass
        }

        var characters = Array(displayed)
        let removed = characters.removeLast()
        let removedLength = settings.codeTable.encode(String(removed)).unicodeScalars.count
        displayed = String(characters)
        if let rebuilt = VietWord(displayed: displayed), !displayed.isEmpty {
            word = rebuilt
            raw = rebuilt.keys(method: settings.method)
            typed = raw
            hadUndo = false
        } else {
            reset()
        }
        // A legacy-encoded letter can take two characters; delete them all.
        return removedLength == 1 ? .pass : .replace(VietOutput(backspaces: removedLength, text: ""), deliverKey: false)
    }

    /// After deleting the key that broke the word ("banv" ⌫), go back to composing when the remaining keys form a
    /// Vietnamese prefix that looks exactly like what is on screen.
    private func resumeVietnameseIfPossible() {
        var rebuilt = VietWord()
        for character in raw {
            rebuilt.type(character, method: settings.method)
        }
        guard rebuilt.validity != .invalid, rebuilt.rendered(modernStyle: settings.modernStyle) == raw else {
            return
        }
        word = rebuilt
        showsRaw = false
    }

    /// ESC: show the keys exactly as typed ("úẻ" → "user", "mesage" → "message").
    private func restoreTypedKeys() -> VietAction {
        guard !typed.isEmpty, displayed != typed else {
            reset()
            return .pass
        }
        let old = displayed
        showsRaw = true
        keepsRaw = true
        raw = typed
        displayed = typed
        return .replace(edit(from: old, to: typed), deliverKey: false)
    }

    // MARK: - Edits

    private func action(from old: String, to new: String, typed: String) -> VietAction {
        let change = edit(from: old, to: new)
        if change.backspaces == 0, change.text == settings.codeTable.encode(typed) {
            return .pass
        }
        return .replace(change, deliverKey: false)
    }

    /// Backspaces and text that turn `old` into `new` on screen, in the output code table.
    func edit(from old: String, to new: String) -> VietOutput {
        let oldScalars = Array(settings.codeTable.encode(old).unicodeScalars)
        let newScalars = Array(settings.codeTable.encode(new).unicodeScalars)
        var common = 0
        while common < oldScalars.count, common < newScalars.count, oldScalars[common] == newScalars[common] {
            common += 1
        }
        var text = String.UnicodeScalarView()
        text.append(contentsOf: newScalars[common...])
        return VietOutput(backspaces: oldScalars.count - common, text: String(text))
    }
}

extension VietWord {
    /// Keys that type this word, used as the "typed keys" after a backspace.
    func keys(method: VietInputMethod) -> String {
        var result = ""
        for letter in letters {
            let base = letter.isUpper ? Character(letter.base.uppercased()) : letter.base
            result.append(base)
            switch (method, letter.mark) {
            case (_, .plain):
                break
            case (.vni, .circumflex):
                result.append("6")
            case (.vni, .horn):
                result.append("7")
            case (.vni, .breve):
                result.append("8")
            case (_, .circumflex):
                result.append(letter.base)
            case (_, .horn), (_, .breve):
                result.append("w")
            }
            if letter.stroke {
                result.append(method == .vni ? "9" : "d")
            }
        }
        if tone != .level {
            let telexTones: [Character] = ["s", "f", "r", "x", "j"]
            result.append(method == .vni ? Character(String(tone.rawValue)) : telexTones[tone.rawValue - 1])
        }
        return result
    }
}
