// MIT License
// Copyright (c) 2026 MacUtils

import Foundation

enum VietMark: Equatable {
    case plain, circumflex, breve, horn
}

/// `level` is thanh ngang (no tone mark); then sắc, huyền, hỏi, ngã, nặng in the usual key order.
enum VietTone: Int, CaseIterable {
    case level, acute, grave, hook, tilde, dot
}

struct VietLetter: Equatable {
    /// Lowercase ASCII letter (or digit for literal VNI keys).
    var base: Character
    var isUpper: Bool
    var mark: VietMark = .plain
    /// d → đ.
    var stroke = false

    static let vowelBases: Set<Character> = ["a", "e", "i", "o", "u", "y"]

    var isVowel: Bool {
        Self.vowelBases.contains(base)
    }

    /// Letter with its mark but without tone, lowercase: "â", "ơ", "đ".
    var plain: String {
        rendered(tone: .level, uppercase: false)
    }

    func rendered(tone: VietTone) -> String {
        rendered(tone: tone, uppercase: isUpper)
    }

    private func rendered(tone: VietTone, uppercase: Bool) -> String {
        if stroke {
            return uppercase ? "Đ" : "đ"
        }
        var text = String(base)
        if let scalar = Self.markScalars[mark] {
            text.unicodeScalars.append(scalar)
        }
        if let scalar = Self.toneScalars[tone] {
            text.unicodeScalars.append(scalar)
        }
        text = text.precomposedStringWithCanonicalMapping
        return uppercase ? text.uppercased() : text
    }

    private static let markScalars: [VietMark: Unicode.Scalar] = [
        .circumflex: "\u{0302}",
        .breve: "\u{0306}",
        .horn: "\u{031B}"
    ]

    private static let toneScalars: [VietTone: Unicode.Scalar] = [
        .acute: "\u{0301}",
        .grave: "\u{0300}",
        .hook: "\u{0309}",
        .tilde: "\u{0303}",
        .dot: "\u{0323}"
    ]

    /// Splits a displayed character back into letter and tone; nil for anything that is not a letter.
    static func decompose(_ character: Character) -> (letter: Self, tone: VietTone)? {
        let text = String(character)
        let isUpper = text != text.lowercased()
        let lower = text.lowercased()
        if lower == "đ" {
            return (Self(base: "d", isUpper: isUpper, stroke: true), .level)
        }
        let scalars = Array(lower.decomposedStringWithCanonicalMapping.unicodeScalars)
        guard let first = scalars.first, first.isASCII, CharacterSet.lowercaseLetters.contains(first) else {
            return nil
        }
        var letter = Self(base: Character(first), isUpper: isUpper)
        var tone = VietTone.level
        for scalar in scalars.dropFirst() {
            if let mark = markScalars.first(where: { $0.value == scalar })?.key {
                letter.mark = mark
            } else if let found = toneScalars.first(where: { $0.value == scalar })?.key {
                tone = found
            } else {
                return nil
            }
        }
        return (letter, tone)
    }
}
