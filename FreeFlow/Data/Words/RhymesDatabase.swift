//
//  RhymesDatabase.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 20/05/2026.
//

import Foundation

struct RhymesDatabase {
    /// Combines the broken-down parts-of-speech lists back into one coordinated master array
    static let words: [WordMetadata] = {
        return NounVocabulary.source
             + VerbVocabulary.source
             + AdjectiveVocabulary.source
             + AdverbVocabulary.source
    }()
    
    static let genericRhymes: [String] = [
        "flow", "glow", "show", "grow", "know", "blow", "row", "throw", "pro", "tempo"
    ]
    
    /// Safely cleans up string variations and pulls corresponding rhymes
    static func getRhymes(for word: String) -> [String] {
        let cleanWord = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return words.first(where: { $0.text == cleanWord })?.rhymes ?? genericRhymes.shuffled()
    }
    
    /// Looks up an explicit structural word entry by key string
    static func findWord(_ keyword: String) -> WordMetadata {
        let clean = keyword.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return words.first(where: { $0.text == clean }) ?? WordMetadata(
            text: "flow",
            type: .noun,
            rhymes: genericRhymes
        )
    }
}
