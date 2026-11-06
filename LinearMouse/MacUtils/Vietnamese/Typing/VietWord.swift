// MIT License
// Copyright (c) 2026 MacUtils

import Foundation

enum VietInputMethod: String, CaseIterable {
    case telex
    case vni
    /// Telex where "w" alone stays "w" (it only adds a horn / breve to a vowel).
    case simpleTelex
}

/// The word being typed: letters with marks plus one tone for the whole word.
///
/// Keys are applied one by one. A key that could add a tone, mark or stroke does so only when the word can
/// still be a Vietnamese syllable; otherwise it is typed as a plain letter. Typing the same modifier again
/// removes it and types the key itself ("cas" + "s" → "cas"), as Unikey does.
struct VietWord: Equatable {
    private(set) var letters: [VietLetter] = []
    private(set) var tone: VietTone = .level
    private var toneUndone = false
    private var markUndone = false
    private var strokeUndone = false
    private var lastKey: Character?

    var isEmpty: Bool {
        letters.isEmpty
    }

    init() {}

    init(letters: [VietLetter], tone: VietTone) {
        self.letters = letters
        self.tone = tone
    }

    /// Rebuilds a word from text already on screen (after a backspace).
    init?(displayed text: String) {
        for character in text {
            guard let (letter, tone) = VietLetter.decompose(character) else {
                return nil
            }
            letters.append(letter)
            if tone != .level {
                self.tone = tone
            }
        }
    }

    var validity: VietValidity {
        VietSyllable.validity(letters, tone: tone)
    }

    func rendered(modernStyle: Bool) -> String {
        let toneIndex = tone == .level ? nil : VietSyllable.toneIndex(letters, modernStyle: modernStyle)
        return letters.enumerated()
            .map { index, letter in
                letter.rendered(tone: index == toneIndex ? tone : .level)
            }
            .joined()
    }

    mutating func type(_ key: Character, method: VietInputMethod) {
        guard let lower = key.lowercased().first else {
            return
        }
        if !applyModifier(lower, key: key, method: method) {
            appendLiteral(key)
        }
        completeHorns()
        lastKey = lower
    }

    // MARK: - Modifiers

    private mutating func applyModifier(_ lower: Character, key: Character, method: VietInputMethod) -> Bool {
        switch method {
        case .telex, .simpleTelex:
            switch lower {
            case "s":
                return applyTone(.acute, key: key)
            case "f":
                return applyTone(.grave, key: key)
            case "r":
                return applyTone(.hook, key: key)
            case "x":
                return applyTone(.tilde, key: key)
            case "j":
                return applyTone(.dot, key: key)
            case "z":
                return removeTone()
            case "a", "e", "o":
                return applyDoubledVowel(lower, key: key)
            case "w":
                return applyHorn(targets: ["a", "o", "u"], key: key, standalone: method == .telex)
            // Only right after the initial d, so English "did" / "dad" are not touched.
            case "d":
                return letters.count == 1 && applyStroke(key: key)
            default:
                return false
            }
        case .vni:
            switch lower {
            case "1":
                return applyTone(.acute, key: key)
            case "2":
                return applyTone(.grave, key: key)
            case "3":
                return applyTone(.hook, key: key)
            case "4":
                return applyTone(.tilde, key: key)
            case "5":
                return applyTone(.dot, key: key)
            case "0":
                return removeTone()
            case "6":
                return applyCircumflex(targets: ["a", "e", "o"], key: key)
            case "7":
                return applyHorn(targets: ["o", "u"], key: key, standalone: false)
            case "8":
                return applyHorn(targets: ["a"], key: key, standalone: false)
            case "9":
                return applyStroke(key: key)
            default:
                return false
            }
        }
    }

    /// Applies `change` to a copy and keeps it only if the word can still be Vietnamese.
    private mutating func attempt(_ change: (inout Self) -> Void) -> Bool {
        var trial = self
        change(&trial)
        trial.completeHorns()
        guard trial.validity != .invalid else {
            return false
        }
        self = trial
        return true
    }

    private var nucleus: Range<Int> {
        VietSyllable.parse(letters).nucleus
    }

    private mutating func applyTone(_ newTone: VietTone, key: Character) -> Bool {
        guard !nucleus.isEmpty else {
            return false
        }
        if tone == newTone {
            tone = .level
            toneUndone = true
            appendLiteral(key)
            return true
        }
        guard !toneUndone else {
            return false
        }
        return attempt { $0.tone = newTone }
    }

    private mutating func removeTone() -> Bool {
        guard tone != .level else {
            return false
        }
        tone = .level
        return true
    }

    /// Telex "aa" / "ee" / "oo". Typed later in the word ("tien" + "e" → "tiên") it only counts when just final
    /// consonants follow the vowel, and after a tone only if there is a final ("tiengse" → "tiếng"), so English
    /// "these", "there", "queue", "reset" stay English.
    private mutating func applyDoubledVowel(_ vowel: Character, key: Character) -> Bool {
        let candidates = nucleus.filter { index in
            guard letters[index].base == vowel else {
                return false
            }
            if lastKey == vowel, index == letters.count - 1 {
                return true
            }
            let after = letters[(index + 1)...]
            return after.allSatisfy { !$0.isVowel } && (tone == .level || !after.isEmpty)
        }
        return markVowel(candidates: candidates, key: key) { _ in .circumflex }
    }

    private mutating func applyCircumflex(targets: Set<Character>, key: Character) -> Bool {
        markVowel(candidates: nucleus.filter { targets.contains(letters[$0].base) }, key: key) { _ in .circumflex }
    }

    /// Puts the mark on the last candidate vowel that keeps the word valid ("chua" + w → "chưa", not "chuă").
    /// Typing the mark again on a vowel that already has it removes it.
    private mutating func markVowel(
        candidates: [Int],
        key: Character,
        mark: (VietLetter) -> VietMark
    ) -> Bool {
        guard !candidates.isEmpty else {
            return false
        }
        if let marked = candidates.last(where: { letters[$0].mark == mark(letters[$0]) }) {
            letters[marked].mark = .plain
            markUndone = true
            appendLiteral(key)
            return true
        }
        guard !markUndone else {
            return false
        }
        for index in candidates.reversed() {
            let wanted = mark(letters[index])
            if attempt({ $0.letters[index].mark = wanted }) {
                return true
            }
        }
        return false
    }

    private mutating func applyHorn(targets: Set<Character>, key: Character, standalone: Bool) -> Bool {
        let vowels = nucleus
        // "uo" + w → "ươ".
        if targets.contains("u"),
           let index = vowels.first(where: { letters[$0].base == "u" && vowels.contains($0 + 1) && letters[$0 + 1]
                   .base == "o"
           }) {
            // Nothing after the o yet: "uơ" (thuở). completeHorns() turns it into "ươ" once more letters come.
            let oIsLast = index + 1 == letters.count - 1
            if letters[index + 1].mark == .horn, letters[index].mark == .horn || oIsLast {
                letters[index].mark = .plain
                letters[index + 1].mark = .plain
                markUndone = true
                appendLiteral(key)
                return true
            }
            guard !markUndone else {
                return false
            }
            return attempt {
                if !oIsLast {
                    $0.letters[index].mark = .horn
                }
                $0.letters[index + 1].mark = .horn
            }
        }
        let candidates = vowels.filter { targets.contains(letters[$0].base) }
        if !candidates.isEmpty {
            return markVowel(candidates: candidates, key: key) { $0.base == "a" ? .breve : .horn }
        }
        // Telex "w" on its own types "ư" ("tw" → "tư").
        guard standalone, !markUndone else {
            return false
        }
        return attempt { $0.letters.append(VietLetter(base: "u", isUpper: key.isUppercase, mark: .horn)) }
    }

    private mutating func applyStroke(key: Character) -> Bool {
        guard let first = letters.first, first.base == "d" else {
            return false
        }
        if first.stroke {
            letters[0].stroke = false
            strokeUndone = true
            appendLiteral(key)
            return true
        }
        guard !strokeUndone else {
            return false
        }
        return attempt { $0.letters[0].stroke = true }
    }

    private mutating func appendLiteral(_ key: Character) {
        guard let lower = key.lowercased().first else {
            return
        }
        letters.append(VietLetter(base: lower, isUpper: key.isUppercase))
    }

    /// "ưo" / "uơ" followed by more letters is always "ươ" ("nguwoi" → "ngươi", "thuơng" → "thương").
    private mutating func completeHorns() {
        let vowels = nucleus
        guard let index = vowels.first(where: { vowels.contains($0 + 1) && letters[$0].base == "u" && letters[$0 + 1]
                      .base == "o"
              }),
              index + 2 < letters.count
        else {
            return
        }
        let first = letters[index].mark
        let second = letters[index + 1].mark
        if (first == .horn && second == .plain) || (first == .plain && second == .horn) {
            letters[index].mark = .horn
            letters[index + 1].mark = .horn
        }
    }
}
