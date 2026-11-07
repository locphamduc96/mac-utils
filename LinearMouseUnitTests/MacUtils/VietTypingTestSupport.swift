// MIT License
// Copyright (c) 2026 MacUtils

@testable import LinearMouse

enum VietTypingTestSupport {
    /// Replays keys through the engine and applies its edits to a simulated text field.
    /// "<" = backspace, "⎋" = escape, "⏎" = return.
    static func type(_ keys: String, settings: VietTypingSettings = VietTypingSettings()) -> String {
        type(keys, engine: VietTypingEngine(settings: settings))
    }

    static func type(_ keys: String, engine: VietTypingEngine) -> String {
        engine.reset()
        var screen = String.UnicodeScalarView()
        for key in keys {
            let input: VietKey
            switch key {
            case "<":
                input = .backspace
            case "⎋":
                input = .escape
            case "⏎":
                input = .commit
            default:
                input = .character(key)
            }
            switch engine.process(input) {
            case .pass:
                switch input {
                case .backspace:
                    if !screen.isEmpty {
                        screen.removeLast()
                    }
                case .commit:
                    screen.append("\n")
                case let .character(character):
                    screen.append(contentsOf: String(character).unicodeScalars)
                default:
                    break
                }
            case let .replace(output, deliverKey):
                screen.removeLast(min(output.backspaces, screen.count))
                screen.append(contentsOf: output.text.unicodeScalars)
                if deliverKey, input == .commit {
                    screen.append("\n")
                }
            }
        }
        return String(screen)
    }

    static func allSyllables() -> [VietWord] {
        var result: [VietWord] = []
        for initial in VietSyllable.initials {
            // "oo" (xoong) needs a third o in Telex; covered by testTelexWords.
            for nucleus in VietSyllable.nuclei.keys where nucleus != "oo" {
                for final in VietSyllable.finals {
                    for tone in VietTone.allCases {
                        let text = initial + nucleus + final
                        guard var word = VietWord(displayed: text) else {
                            continue
                        }
                        word.setToneForTesting(tone)
                        if VietSyllable.parse(word.letters).nucleus.count == nucleus.count,
                           word.validity == .complete {
                            result.append(word)
                        }
                    }
                }
            }
        }
        return result
    }

    /// Canonical order (modifier right after its letter, tone last), tone before the final consonant,
    /// and marks typed after the whole word (Telex).
    static func keyOrders(for word: VietWord, method: VietInputMethod) -> [String] {
        let canonical = word.keys(method: method)
        var orders = [canonical]
        let parts = VietSyllable.parse(word.letters)
        if word.tone != .level, !parts.final.isEmpty {
            var plain = word
            plain.setToneForTesting(.level)
            let finalLetters = Array(word.letters[parts.final])
            var head = plain
            head.dropLastForTesting(finalLetters.count)
            let toneKey = String(word.keys(method: method).last!)
            let tail = finalLetters.map { String($0.base) }.joined()
            orders.append(head.keys(method: method) + toneKey + tail)
        }
        if method == .telex {
            // Bare letters, then every mark (đ, circumflex, horn / breve), then the tone: "doidor" → "đổi".
            var bare = ""
            var marks = ""
            for (index, letter) in word.letters.enumerated() {
                bare.append(letter.base)
                if letter.stroke {
                    marks.append("d")
                }
                // "ươ" is typed with a single w.
                let pairedHorn = letter.mark == .horn && letter.base == "o" && index > 0
                    && word.letters[index - 1].mark == .horn && word.letters[index - 1].base == "u"
                switch letter.mark {
                case .circumflex:
                    marks.append(letter.base)
                case .horn where !pairedHorn, .breve:
                    marks.append("w")
                default:
                    break
                }
            }
            let toneKey = word.tone == .level ? "" : String(word.keys(method: .telex).last!)
            orders.append(bare + marks + toneKey)
        }
        return orders
    }
}
