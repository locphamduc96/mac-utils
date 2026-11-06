// MIT License
// Copyright (c) 2026 MacUtils

import Foundation

enum VietValidity: Equatable {
    /// Cannot become a Vietnamese syllable whatever is typed next.
    case invalid
    /// Can still become one (e.g. "ngh", "tiê", "thuo").
    case prefix
    /// A complete syllable (e.g. "tiếng", "quá").
    case complete
}

/// Vietnamese syllable rules: initial consonant + vowel nucleus + final consonant, and tone placement.
enum VietSyllable {
    struct Parts {
        let initial: Range<Int>
        let nucleus: Range<Int>
        let final: Range<Int>
    }

    static func parse(_ letters: [VietLetter]) -> Parts {
        var consonantEnd = 0
        while consonantEnd < letters.count, !letters[consonantEnd].isVowel {
            consonantEnd += 1
        }
        var initialEnd = consonantEnd
        // "qu" and "gi" (before another vowel) are initials: the u / i is not part of the nucleus.
        if consonantEnd == 1, consonantEnd < letters.count {
            let first = letters[0]
            let next = letters[1]
            if first.base == "q", next.base == "u" {
                initialEnd = 2
            } else if first.base == "g", !first.stroke, next.base == "i", next.mark == .plain,
                      letters.count > 2, letters[2].isVowel {
                initialEnd = 2
            }
        }
        var nucleusEnd = initialEnd
        while nucleusEnd < letters.count, letters[nucleusEnd].isVowel {
            nucleusEnd += 1
        }
        return Parts(
            initial: 0 ..< initialEnd,
            nucleus: initialEnd ..< nucleusEnd,
            final: nucleusEnd ..< letters.count
        )
    }

    // MARK: - Tables

    static let initials: Set<String> = [
        "", "b", "c", "ch", "d", "đ", "g", "gh", "gi", "h", "k", "kh", "l", "m", "n", "ng", "ngh", "nh",
        "p", "ph", "qu", "r", "s", "t", "th", "tr", "v", "x"
    ]

    private static let initialPrefixes: Set<String> = prefixes(of: initials)

    static let finals: Set<String> = ["", "c", "ch", "m", "n", "ng", "nh", "p", "t"]

    private static let finalPrefixes: Set<String> = prefixes(of: finals)

    private static let stopFinals: Set<String> = ["c", "ch", "p", "t"]

    struct NucleusRule {
        let requiresFinal: Bool
        let allowsFinal: Bool
    }

    private static let openNuclei = ["a", "e", "ê", "i", "o", "ô", "ơ", "u", "ư", "y", "oa", "oe", "uê", "uy"]
    private static let closedNuclei = ["ă", "â", "iê", "yê", "uâ", "uô", "ươ", "oă", "uyê", "oo"]
    private static let finalLessNuclei = [
        "ai", "ao", "au", "ay", "âu", "ây", "eo", "êu", "ia", "iu", "oi", "ôi", "ơi", "ua", "ui", "ưa", "ưi",
        "ưu", "uơ", "iêu", "yêu", "oai", "oao", "oay", "oeo", "uây", "uôi", "uya", "uyu", "ươi", "ươu"
    ]

    static let nuclei: [String: NucleusRule] = {
        var table: [String: NucleusRule] = [:]
        for nucleus in openNuclei {
            table[nucleus] = NucleusRule(requiresFinal: false, allowsFinal: true)
        }
        for nucleus in closedNuclei {
            table[nucleus] = NucleusRule(requiresFinal: true, allowsFinal: true)
        }
        for nucleus in finalLessNuclei {
            table[nucleus] = NucleusRule(requiresFinal: false, allowsFinal: false)
        }
        return table
    }()

    /// Nuclei as letters, for prefix matching against partly typed vowels.
    private static let nucleusLetters: [(key: String, letters: [VietLetter], rule: NucleusRule)] = nuclei
        .map { key, rule in
            (key, key.map { VietLetter.decompose($0)!.letter }, rule)
        }

    private static func prefixes(of words: Set<String>) -> Set<String> {
        var result: Set<String> = []
        for word in words {
            for length in 0 ... word.count {
                result.insert(String(word.prefix(length)))
            }
        }
        return result
    }

    // MARK: - Validity

    static func validity(_ letters: [VietLetter], tone: VietTone) -> VietValidity {
        guard !letters.isEmpty else {
            return .prefix
        }
        guard letters.allSatisfy({ isVietnameseLetter($0) }) else {
            return .invalid
        }

        let parts = parse(letters)
        let initial = letters[parts.initial].map { $0.stroke ? "đ" : String($0.base) }.joined()
        let vowels = Array(letters[parts.nucleus])
        let finalLetters = Array(letters[parts.final])

        guard !vowels.isEmpty else {
            return initialPrefixes.contains(initial) && tone == .level ? .prefix : .invalid
        }
        guard initials.contains(initial), spellingAllowed(initial: initial, firstVowel: vowels[0]),
              !finalLetters.contains(where: \.isVowel) else {
            return .invalid
        }

        let final = finalLetters.map { String($0.base) }.joined()
        let exact = vowels.map(\.plain).joined()

        if final.isEmpty {
            guard !candidates(for: vowels, sameLength: false).isEmpty else {
                return .invalid
            }
            if let rule = nuclei[exact], !rule.requiresFinal {
                return .complete
            }
            return .prefix
        }

        guard finalPrefixes.contains(final) else {
            return .invalid
        }
        // c / ch / p / t only take sắc or nặng (or no tone).
        if stopFinals.contains(final), ![.level, .acute, .dot].contains(tone) {
            return .invalid
        }
        let completions = finals.filter { !$0.isEmpty && $0.hasPrefix(final) }
        let possible = candidates(for: vowels, sameLength: true).contains { candidate in
            candidate.rule.allowsFinal && completions.contains {
                finalAllowed($0, nucleus: candidate.key, initial: initial)
            }
        }
        guard possible else {
            return .invalid
        }
        if finals.contains(final), let rule = nuclei[exact], rule.allowsFinal,
           finalAllowed(final, nucleus: exact, initial: initial) {
            return .complete
        }
        return .prefix
    }

    private static func isVietnameseLetter(_ letter: VietLetter) -> Bool {
        guard let ascii = letter.base.asciiValue, ascii >= 97, ascii <= 122 else {
            return false
        }
        return !"fjwz".contains(letter.base)
    }

    /// Nuclei the typed vowels can still turn into: same letters, and any mark typed so far must match
    /// (an unmarked vowel may get its mark later, e.g. "tien" + "e" → "tiên").
    private static func candidates(
        for vowels: [VietLetter],
        sameLength: Bool
    ) -> [(key: String, letters: [VietLetter], rule: NucleusRule)] {
        nucleusLetters.filter { candidate in
            guard sameLength ? candidate.letters.count == vowels.count : candidate.letters.count >= vowels.count
            else {
                return false
            }
            return zip(vowels, candidate.letters).allSatisfy { typed, wanted in
                typed.base == wanted.base && (typed.mark == .plain || typed.mark == wanted.mark)
            }
        }
    }

    private static func spellingAllowed(initial: String, firstVowel: VietLetter) -> Bool {
        let front = firstVowel.base == "e" || firstVowel.base == "i" || firstVowel.base == "y"
        switch initial {
        case "c":
            return !front
        case "k":
            return front
        case "g":
            return firstVowel.base != "e"
        case "gh", "ngh":
            return firstVowel.base == "e" || firstVowel.base == "i"
        case "ng":
            return firstVowel.base != "e" && firstVowel.base != "i"
        default:
            return true
        }
    }

    private static func finalAllowed(_ final: String, nucleus: String, initial: String) -> Bool {
        // Loanwords only: xoong, boong, soóc.
        if nucleus == "oo" {
            return final == "ng" || final == "c"
        }
        switch final {
        case "ch", "nh":
            return ["a", "ê", "i", "y", "oa", "uê", "uy"].contains(nucleus)
        case "c", "ng":
            // "giếng": the i of "iê" is merged into the initial "gi".
            if initial == "gi", nucleus == "ê" {
                return true
            }
            return !["ê", "i", "y", "ơ", "uy", "uê"].contains(nucleus)
        default:
            return true
        }
    }

    // MARK: - Tone placement

    /// Index into `letters` of the vowel carrying the tone, or nil without a nucleus.
    static func toneIndex(_ letters: [VietLetter], modernStyle: Bool) -> Int? {
        let parts = parse(letters)
        guard !parts.nucleus.isEmpty else {
            return nil
        }
        let vowels = Array(letters[parts.nucleus])
        let start = parts.nucleus.lowerBound
        // A vowel with a mark takes the tone; in "ươ" the ơ.
        if let marked = vowels.lastIndex(where: { $0.mark != .plain }) {
            return start + marked
        }
        switch vowels.count {
        case 1:
            return start
        case 2:
            if !parts.final.isEmpty {
                return start + 1
            }
            let bases = String(vowels.map(\.base))
            return modernStyle && ["oa", "oe", "uy"].contains(bases) ? start + 1 : start
        default:
            return start + 1
        }
    }
}
