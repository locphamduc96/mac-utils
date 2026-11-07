// MIT License
// Copyright (c) 2026 MacUtils

import AppKit

/// macOS's English spelling dictionary, for words whose doubled letter cancelled a tone ("message", "issue").
enum EnglishDictionary {
    static func contains(_ word: String) -> Bool {
        guard word.count > 1, word.allSatisfy(\.isLetter) else {
            return false
        }
        let misspelled = NSSpellChecker.shared.checkSpelling(
            of: word,
            startingAt: 0,
            language: "en",
            wrap: false,
            inSpellDocumentWithTag: 0,
            wordCount: nil
        )
        return misspelled.location == NSNotFound
    }
}
