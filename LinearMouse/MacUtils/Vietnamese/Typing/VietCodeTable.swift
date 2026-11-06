// MIT License
// Copyright (c) 2026 MacUtils
// TCVN3 and VNI-Windows code points cross-checked against xkey's tables (https://github.com/xmannv/xkey), MIT License.

import Foundation

enum VietCodeTable: String, CaseIterable {
    case unicode
    /// TCVN3 (ABC): one byte per letter, for .Vn fonts.
    case tcvn3
    /// VNI-Windows: base letter followed by accent bytes, for VNI- fonts.
    case vniWindows

    /// Converts Unicode text to the code table. Legacy bytes are sent as U+0000–U+00FF, which is how
    /// the legacy fonts expect them.
    func encode(_ text: String) -> String {
        guard self != .unicode else {
            return text
        }
        var result = ""
        for character in text {
            result += encode(character) ?? String(character)
        }
        return result
    }

    private func encode(_ character: Character) -> String? {
        guard let (letter, tone) = VietLetter.decompose(character),
              letter.stroke || letter.mark != .plain || tone != .level
        else {
            return nil
        }
        switch self {
        case .unicode:
            return nil
        case .tcvn3:
            return Self.tcvn3(letter, tone: tone)
        case .vniWindows:
            return Self.vniWindows(letter, tone: tone)
        }
    }

    private static func scalars(_ values: [UInt8]) -> String {
        String(String.UnicodeScalarView(values.map { Unicode.Scalar($0) }))
    }

    // MARK: - TCVN3

    /// [no tone, sắc, huyền, hỏi, ngã, nặng]; uppercase toned letters share the lowercase code.
    private static let tcvn3Table: [String: [UInt8]] = [
        "a": [0x61, 0xB8, 0xB5, 0xB6, 0xB7, 0xB9],
        "ă": [0xA8, 0xBE, 0xBB, 0xBC, 0xBD, 0xC6],
        "â": [0xA9, 0xCA, 0xC7, 0xC8, 0xC9, 0xCB],
        "e": [0x65, 0xD0, 0xCC, 0xCE, 0xCF, 0xD1],
        "ê": [0xAA, 0xD5, 0xD2, 0xD3, 0xD4, 0xD6],
        "i": [0x69, 0xDD, 0xD7, 0xD8, 0xDC, 0xDE],
        "o": [0x6F, 0xE3, 0xDF, 0xE1, 0xE2, 0xE4],
        "ô": [0xAB, 0xE8, 0xE5, 0xE6, 0xE7, 0xE9],
        "ơ": [0xAC, 0xED, 0xEA, 0xEB, 0xEC, 0xEE],
        "u": [0x75, 0xF3, 0xEF, 0xF1, 0xF2, 0xF4],
        "ư": [0xAD, 0xF8, 0xF5, 0xF6, 0xF7, 0xF9],
        "y": [0x79, 0xFD, 0xFA, 0xFB, 0xFC, 0xFE]
    ]

    private static let tcvn3Uppercase: [String: UInt8] = [
        "ă": 0xA1, "â": 0xA2, "ê": 0xA3, "ô": 0xA4, "ơ": 0xA5, "ư": 0xA6
    ]

    private static func tcvn3(_ letter: VietLetter, tone: VietTone) -> String? {
        if letter.stroke {
            return scalars([letter.isUpper ? 0xA7 : 0xAE])
        }
        let plain = letter.plain
        if tone == .level, letter.isUpper, let upper = tcvn3Uppercase[plain] {
            return scalars([upper])
        }
        guard let row = tcvn3Table[plain] else {
            return nil
        }
        return scalars([row[tone.rawValue]])
    }

    // MARK: - VNI-Windows

    /// Accent byte for [no tone, sắc, huyền, hỏi, ngã, nặng], lowercase then uppercase.
    private static let vniTone: [[UInt8]] = [
        [0, 0xF9, 0xF8, 0xFB, 0xF5, 0xEF],
        [0, 0xD9, 0xD8, 0xDB, 0xD5, 0xCF]
    ]
    private static let vniCircumflex: [[UInt8]] = [
        [0xE2, 0xE1, 0xE0, 0xE5, 0xE3, 0xE4],
        [0xC2, 0xC1, 0xC0, 0xC5, 0xC3, 0xC4]
    ]
    private static let vniBreve: [[UInt8]] = [
        [0xEA, 0xE9, 0xE8, 0xFA, 0xFC, 0xEB],
        [0xCA, 0xC9, 0xC8, 0xDA, 0xDC, 0xCB]
    ]
    /// i and ỵ are single bytes.
    private static let vniI: [[UInt8]] = [
        [0x69, 0xED, 0xEC, 0xE6, 0xF3, 0xF2],
        [0x49, 0xCD, 0xCC, 0xC6, 0xD3, 0xD2]
    ]

    private static func vniWindows(_ letter: VietLetter, tone: VietTone) -> String? {
        let upper = letter.isUpper ? 1 : 0
        let toneIndex = tone.rawValue
        if letter.stroke {
            return scalars([letter.isUpper ? 0xD1 : 0xF1])
        }
        let base = UInt8(letter.base.asciiValue! - (letter.isUpper ? 32 : 0))
        switch (letter.base, letter.mark) {
        case ("i", .plain):
            return scalars([vniI[upper][toneIndex]])
        case ("y", .plain) where tone == .dot:
            return scalars([letter.isUpper ? 0xCE : 0xEE])
        case (_, .circumflex):
            return scalars([base, vniCircumflex[upper][toneIndex]])
        case (_, .breve):
            return scalars([base, vniBreve[upper][toneIndex]])
        case (_, .horn):
            // ơ / ư are single letters (ô / ö in the VNI font), followed by the tone byte.
            let horned: UInt8 = letter.base == "o" ? (letter.isUpper ? 0xD4 : 0xF4) : (letter.isUpper ? 0xD6 : 0xF6)
            return scalars(tone == .level ? [horned] : [horned, vniTone[upper][toneIndex]])
        default:
            return scalars([base, vniTone[upper][toneIndex]])
        }
    }
}
