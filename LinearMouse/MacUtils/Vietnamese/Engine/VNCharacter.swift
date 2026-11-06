// Vendored from https://github.com/xmannv/xkey @ 398e78e (MIT License, see ThirdPartyNotices/xkey.txt).
// Keep local edits minimal so upstream fixes can be re-applied.

//
//  VNCharacter.swift
//  XKey
//
//  Vietnamese character definitions and mappings
//

import Foundation

// MARK: - Vietnamese Tones

enum VNTone: Int, CaseIterable, Codable {
    case none = 0      // No tone
    case acute = 1     // Sắc (á)
    case grave = 2     // Huyền (à)
    case hookAbove = 3 // Hỏi (ả)
    case tilde = 4     // Ngã (ã)
    case dotBelow = 5  // Nặng (ạ)
    
    var displayName: String {
        switch self {
        case .none: return "Không dấu"
        case .acute: return "Sắc"
        case .grave: return "Huyền"
        case .hookAbove: return "Hỏi"
        case .tilde: return "Ngã"
        case .dotBelow: return "Nặng"
        }
    }
}

// MARK: - Vietnamese Vowels

enum VNVowel: String, CaseIterable {
    // Basic vowels
    case a, e, i, o, u, y
    
    // Vowels with circumflex (^)
    case aCircumflex = "â"
    case eCircumflex = "ê"
    case oCircumflex = "ô"
    
    // Vowels with breve (˘)
    case aBreve = "ă"
    
    // Vowels with horn (+)
    case oHorn = "ơ"
    case uHorn = "ư"
    
    var baseCharacter: Character {
        switch self {
        case .a, .aCircumflex, .aBreve: return "a"
        case .e, .eCircumflex: return "e"
        case .i: return "i"
        case .o, .oCircumflex, .oHorn: return "o"
        case .u, .uHorn: return "u"
        case .y: return "y"
        }
    }
    
    var hasCircumflex: Bool {
        switch self {
        case .aCircumflex, .eCircumflex, .oCircumflex: return true
        default: return false
        }
    }
    
    var hasBreve: Bool {
        self == .aBreve
    }
    
    var hasHorn: Bool {
        self == .oHorn || self == .uHorn
    }
}

// MARK: - Vietnamese Consonants

enum VNConsonant: String, CaseIterable {
    // Single consonants
    case b, c, d, g, h, k, l, m, n, p, q, r, s, t, v, x
    
    // Special consonant
    case dd = "đ"
    
    // Compound consonants
    case ch, gh, gi, kh, ng, ngh, nh, ph, qu, th, tr
    
    var isSingleConsonant: Bool {
        rawValue.count == 1
    }
    
    var isCompoundConsonant: Bool {
        rawValue.count > 1
    }
}

// MARK: - Vowel Sequences

enum VowelSequence: Equatable, Hashable {
    case single(VNVowel)
    case double(VNVowel, VNVowel)
    case triple(VNVowel, VNVowel, VNVowel)
    
    var vowels: [VNVowel] {
        switch self {
        case .single(let v): return [v]
        case .double(let v1, let v2): return [v1, v2]
        case .triple(let v1, let v2, let v3): return [v1, v2, v3]
        }
    }
    
    var length: Int {
        vowels.count
    }
    
    // Check if this is a valid Vietnamese vowel sequence
    var isValid: Bool {
        VowelSequenceValidator.isValid(self)
    }
}

// MARK: - Consonant Sequences

enum ConsonantSequence: Equatable {
    case single(VNConsonant)
    case compound(VNConsonant)
    
    var consonant: VNConsonant {
        switch self {
        case .single(let c), .compound(let c): return c
        }
    }
}

// MARK: - Vietnamese Character

struct VNCharacter: Equatable, Hashable {
    let vowel: VNVowel?
    let consonant: VNConsonant?
    let tone: VNTone
    let isUppercase: Bool
    let plainCharacter: Character?  // For pass-through characters
    
    init(vowel: VNVowel, tone: VNTone = .none, isUppercase: Bool = false) {
        self.vowel = vowel
        self.consonant = nil
        self.tone = tone
        self.isUppercase = isUppercase
        self.plainCharacter = nil
    }

    init(consonant: VNConsonant, isUppercase: Bool = false) {
        self.vowel = nil
        self.consonant = consonant
        self.tone = .none
        self.isUppercase = isUppercase
        self.plainCharacter = nil
    }

    // Initialize from plain character (for pass-through characters)
    init(character: Character) {
        self.vowel = nil
        self.consonant = nil
        self.tone = .none
        self.isUppercase = character.isUppercase
        self.plainCharacter = character
    }

    var isVowel: Bool {
        vowel != nil
    }
    
    var isConsonant: Bool {
        consonant != nil
    }
    
    // Get Unicode scalar value
    func unicode(codeTable: CodeTable) -> String {
        // Return plain character if set (for pass-through)
        if let plain = plainCharacter {
            // For Unicode Compound and CP1258, convert precomposed Vietnamese chars to combining
            if codeTable == .unicodeCompound || codeTable == .vietnameseLocaleCP1258 {
                return VNCharacter.convertToCombining(String(plain), codeTable: codeTable)
            }
            return String(plain)
        }

        if let consonant = consonant {
            let base = consonant.rawValue
            if isUppercase {
                // Only capitalize the first character
                // Example: "tr" → "Tr", not "TR"
                return base.prefix(1).uppercased() + base.dropFirst()
            }
            return base
        }

        if let vowel = vowel {
            let result = VNCharacterMap.getUnicode(
                vowel: vowel,
                tone: tone,
                isUppercase: isUppercase,
                codeTable: codeTable
            )
            return result
        }

        return ""
    }
    
    // MARK: - Combining Character Conversion
    
    /// Convert precomposed Vietnamese characters to combining character sequences
    /// Used for Unicode Compound and CP1258 code tables
    private static func convertToCombining(_ input: String, codeTable: CodeTable) -> String {
        var result = ""
        
        for char in input {
            if let decomposed = decomposedMap[char] {
                // Use full decomposition for Unicode Compound
                // Use partial decomposition for CP1258 (base with diacritic + combining tone)
                if codeTable == .unicodeCompound {
                    result += decomposed.fullDecomposed
                } else {
                    result += decomposed.cp1258Decomposed
                }
            } else {
                result.append(char)
            }
        }
        
        return result
    }
    
    /// Decomposition data for Vietnamese characters
    /// fullDecomposed: base + all combining marks (for Unicode Compound/NFD)
    /// cp1258Decomposed: precomposed base + combining tone (for CP1258)
    private static let decomposedMap: [Character: (fullDecomposed: String, cp1258Decomposed: String)] = {
        // Combining diacritical marks
        let acute = "\u{0301}"      // ́
        let grave = "\u{0300}"      // ̀
        let hookAbove = "\u{0309}"  // ̉
        let tilde = "\u{0303}"      // ̃
        let dotBelow = "\u{0323}"   // ̣
        let circumflex = "\u{0302}" // ̂
        let breve = "\u{0306}"      // ̆
        let horn = "\u{031B}"       // ̛
        
        return [
            // A with diacritics
            "á": ("a" + acute, "a" + acute),
            "à": ("a" + grave, "a" + grave),
            "ả": ("a" + hookAbove, "a" + hookAbove),
            "ã": ("a" + tilde, "a" + tilde),
            "ạ": ("a" + dotBelow, "a" + dotBelow),
            "Á": ("A" + acute, "A" + acute),
            "À": ("A" + grave, "A" + grave),
            "Ả": ("A" + hookAbove, "A" + hookAbove),
            "Ã": ("A" + tilde, "A" + tilde),
            "Ạ": ("A" + dotBelow, "A" + dotBelow),
            
            // Â (a + circumflex)
            "â": ("a" + circumflex, "â"),
            "ấ": ("a" + circumflex + acute, "â" + acute),
            "ầ": ("a" + circumflex + grave, "â" + grave),
            "ẩ": ("a" + circumflex + hookAbove, "â" + hookAbove),
            "ẫ": ("a" + circumflex + tilde, "â" + tilde),
            "ậ": ("a" + circumflex + dotBelow, "â" + dotBelow),
            "Â": ("A" + circumflex, "Â"),
            "Ấ": ("A" + circumflex + acute, "Â" + acute),
            "Ầ": ("A" + circumflex + grave, "Â" + grave),
            "Ẩ": ("A" + circumflex + hookAbove, "Â" + hookAbove),
            "Ẫ": ("A" + circumflex + tilde, "Â" + tilde),
            "Ậ": ("A" + circumflex + dotBelow, "Â" + dotBelow),
            
            // Ă (a + breve)
            "ă": ("a" + breve, "ă"),
            "ắ": ("a" + breve + acute, "ă" + acute),
            "ằ": ("a" + breve + grave, "ă" + grave),
            "ẳ": ("a" + breve + hookAbove, "ă" + hookAbove),
            "ẵ": ("a" + breve + tilde, "ă" + tilde),
            "ặ": ("a" + breve + dotBelow, "ă" + dotBelow),
            "Ă": ("A" + breve, "Ă"),
            "Ắ": ("A" + breve + acute, "Ă" + acute),
            "Ằ": ("A" + breve + grave, "Ă" + grave),
            "Ẳ": ("A" + breve + hookAbove, "Ă" + hookAbove),
            "Ẵ": ("A" + breve + tilde, "Ă" + tilde),
            "Ặ": ("A" + breve + dotBelow, "Ă" + dotBelow),
            
            // E with diacritics
            "é": ("e" + acute, "e" + acute),
            "è": ("e" + grave, "e" + grave),
            "ẻ": ("e" + hookAbove, "e" + hookAbove),
            "ẽ": ("e" + tilde, "e" + tilde),
            "ẹ": ("e" + dotBelow, "e" + dotBelow),
            "É": ("E" + acute, "E" + acute),
            "È": ("E" + grave, "E" + grave),
            "Ẻ": ("E" + hookAbove, "E" + hookAbove),
            "Ẽ": ("E" + tilde, "E" + tilde),
            "Ẹ": ("E" + dotBelow, "E" + dotBelow),
            
            // Ê (e + circumflex)
            "ê": ("e" + circumflex, "ê"),
            "ế": ("e" + circumflex + acute, "ê" + acute),
            "ề": ("e" + circumflex + grave, "ê" + grave),
            "ể": ("e" + circumflex + hookAbove, "ê" + hookAbove),
            "ễ": ("e" + circumflex + tilde, "ê" + tilde),
            "ệ": ("e" + circumflex + dotBelow, "ê" + dotBelow),
            "Ê": ("E" + circumflex, "Ê"),
            "Ế": ("E" + circumflex + acute, "Ê" + acute),
            "Ề": ("E" + circumflex + grave, "Ê" + grave),
            "Ể": ("E" + circumflex + hookAbove, "Ê" + hookAbove),
            "Ễ": ("E" + circumflex + tilde, "Ê" + tilde),
            "Ệ": ("E" + circumflex + dotBelow, "Ê" + dotBelow),
            
            // I with diacritics
            "í": ("i" + acute, "i" + acute),
            "ì": ("i" + grave, "i" + grave),
            "ỉ": ("i" + hookAbove, "i" + hookAbove),
            "ĩ": ("i" + tilde, "i" + tilde),
            "ị": ("i" + dotBelow, "i" + dotBelow),
            "Í": ("I" + acute, "I" + acute),
            "Ì": ("I" + grave, "I" + grave),
            "Ỉ": ("I" + hookAbove, "I" + hookAbove),
            "Ĩ": ("I" + tilde, "I" + tilde),
            "Ị": ("I" + dotBelow, "I" + dotBelow),
            
            // O with diacritics
            "ó": ("o" + acute, "o" + acute),
            "ò": ("o" + grave, "o" + grave),
            "ỏ": ("o" + hookAbove, "o" + hookAbove),
            "õ": ("o" + tilde, "o" + tilde),
            "ọ": ("o" + dotBelow, "o" + dotBelow),
            "Ó": ("O" + acute, "O" + acute),
            "Ò": ("O" + grave, "O" + grave),
            "Ỏ": ("O" + hookAbove, "O" + hookAbove),
            "Õ": ("O" + tilde, "O" + tilde),
            "Ọ": ("O" + dotBelow, "O" + dotBelow),
            
            // Ô (o + circumflex)
            "ô": ("o" + circumflex, "ô"),
            "ố": ("o" + circumflex + acute, "ô" + acute),
            "ồ": ("o" + circumflex + grave, "ô" + grave),
            "ổ": ("o" + circumflex + hookAbove, "ô" + hookAbove),
            "ỗ": ("o" + circumflex + tilde, "ô" + tilde),
            "ộ": ("o" + circumflex + dotBelow, "ô" + dotBelow),
            "Ô": ("O" + circumflex, "Ô"),
            "Ố": ("O" + circumflex + acute, "Ô" + acute),
            "Ồ": ("O" + circumflex + grave, "Ô" + grave),
            "Ổ": ("O" + circumflex + hookAbove, "Ô" + hookAbove),
            "Ỗ": ("O" + circumflex + tilde, "Ô" + tilde),
            "Ộ": ("O" + circumflex + dotBelow, "Ô" + dotBelow),
            
            // Ơ (o + horn)
            "ơ": ("o" + horn, "ơ"),
            "ớ": ("o" + horn + acute, "ơ" + acute),
            "ờ": ("o" + horn + grave, "ơ" + grave),
            "ở": ("o" + horn + hookAbove, "ơ" + hookAbove),
            "ỡ": ("o" + horn + tilde, "ơ" + tilde),
            "ợ": ("o" + horn + dotBelow, "ơ" + dotBelow),
            "Ơ": ("O" + horn, "Ơ"),
            "Ớ": ("O" + horn + acute, "Ơ" + acute),
            "Ờ": ("O" + horn + grave, "Ơ" + grave),
            "Ở": ("O" + horn + hookAbove, "Ơ" + hookAbove),
            "Ỡ": ("O" + horn + tilde, "Ơ" + tilde),
            "Ợ": ("O" + horn + dotBelow, "Ơ" + dotBelow),
            
            // U with diacritics
            "ú": ("u" + acute, "u" + acute),
            "ù": ("u" + grave, "u" + grave),
            "ủ": ("u" + hookAbove, "u" + hookAbove),
            "ũ": ("u" + tilde, "u" + tilde),
            "ụ": ("u" + dotBelow, "u" + dotBelow),
            "Ú": ("U" + acute, "U" + acute),
            "Ù": ("U" + grave, "U" + grave),
            "Ủ": ("U" + hookAbove, "U" + hookAbove),
            "Ũ": ("U" + tilde, "U" + tilde),
            "Ụ": ("U" + dotBelow, "U" + dotBelow),
            
            // Ư (u + horn)
            "ư": ("u" + horn, "ư"),
            "ứ": ("u" + horn + acute, "ư" + acute),
            "ừ": ("u" + horn + grave, "ư" + grave),
            "ử": ("u" + horn + hookAbove, "ư" + hookAbove),
            "ữ": ("u" + horn + tilde, "ư" + tilde),
            "ự": ("u" + horn + dotBelow, "ư" + dotBelow),
            "Ư": ("U" + horn, "Ư"),
            "Ứ": ("U" + horn + acute, "Ư" + acute),
            "Ừ": ("U" + horn + grave, "Ư" + grave),
            "Ử": ("U" + horn + hookAbove, "Ư" + hookAbove),
            "Ữ": ("U" + horn + tilde, "Ư" + tilde),
            "Ự": ("U" + horn + dotBelow, "Ư" + dotBelow),
            
            // Y with diacritics
            "ý": ("y" + acute, "y" + acute),
            "ỳ": ("y" + grave, "y" + grave),
            "ỷ": ("y" + hookAbove, "y" + hookAbove),
            "ỹ": ("y" + tilde, "y" + tilde),
            "ỵ": ("y" + dotBelow, "y" + dotBelow),
            "Ý": ("Y" + acute, "Y" + acute),
            "Ỳ": ("Y" + grave, "Y" + grave),
            "Ỷ": ("Y" + hookAbove, "Y" + hookAbove),
            "Ỹ": ("Y" + tilde, "Y" + tilde),
            "Ỵ": ("Y" + dotBelow, "Y" + dotBelow),
            
            // Đ (d with stroke)
            "đ": ("đ", "đ"),  // Keep as-is (no combining form in standard Unicode)
            "Đ": ("Đ", "Đ")
        ]
    }()
}

// MARK: - Code Tables

enum CodeTable: Int, CaseIterable, Codable {
    case unicode = 0
    case tcvn3 = 1
    case vniWindows = 2
    case unicodeCompound = 3
    case vietnameseLocaleCP1258 = 4
    
    var displayName: String {
        switch self {
        case .unicode: return "Unicode"
        case .tcvn3: return "TCVN3 (ABC)"
        case .vniWindows: return "VNI Windows"
        case .unicodeCompound: return "Unicode Compound"
        case .vietnameseLocaleCP1258: return "Vietnamese Locale CP1258"
        }
    }
    
    var requiresDoubleBackspace: Bool {
        self == .vniWindows || self == .unicodeCompound
    }
}

// MARK: - Input Methods

enum InputMethod: Int, CaseIterable, Codable {
    // NOTE: `allCases` follows declaration order, so `.adaptive` is listed first
    // to appear at the top of the input-method pickers. Raw values are kept stable
    // (adaptive = 4) for Codable persistence — do not renumber.
    case adaptive = 4
    case telex = 0
    case vni = 1
    case simpleTelex1 = 2
    case simpleTelex2 = 3

    var displayName: String {
        switch self {
        case .adaptive: return "Tự nhận kiểu gõ (Telex + VNI)"
        case .telex: return "Telex (w→ư, []→ơư)"
        case .vni: return "VNI"
        case .simpleTelex1: return "Simple Telex 1 (w->w, []→[])"
        case .simpleTelex2: return "Simple Telex 2 (w→ư, []→[])"
        }
    }
}

// MARK: - Key Codes

enum VNKeyCode: UInt16 {
    // Letters
    case a = 0x00, b = 0x0B, c = 0x08, d = 0x02, e = 0x0E
    case f = 0x03, g = 0x05, h = 0x04, i = 0x22, j = 0x26
    case k = 0x28, l = 0x25, m = 0x2E, n = 0x2D, o = 0x1F
    case p = 0x23, q = 0x0C, r = 0x0F, s = 0x01, t = 0x11
    case u = 0x20, v = 0x09, w = 0x0D, x = 0x07, y = 0x10
    case z = 0x06
    
    // Numbers
    case num0 = 0x1D, num1 = 0x12, num2 = 0x13, num3 = 0x14, num4 = 0x15
    case num5 = 0x17, num6 = 0x16, num7 = 0x1A, num8 = 0x1C, num9 = 0x19
    
    // Special keys
    case space = 0x31
    case delete = 0x33
    case enter = 0x24
    case escape = 0x35
    
    // Punctuation
    case minus = 0x1B
    case equals = 0x18
    case leftBracket = 0x21
    case rightBracket = 0x1E
    case backslash = 0x2A
    case semicolon = 0x29
    case quote = 0x27
    case comma = 0x2B
    case period = 0x2F
    case slash = 0x2C
    case grave = 0x32
}

