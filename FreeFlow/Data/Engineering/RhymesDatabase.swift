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
    
    // 🚀 NEW SETUP ADDITION: Dynamically extracts EVERY unique word hiding inside
    // the core entries AND their rhyming buckets for a specific part of speech.
    // This multiplies your vocabulary variation by 10x instantly.
    static func allUniqueWords(for type: WordType) -> [String] {
        let typedSources = words.filter { $0.type == type }
        var uniqueSet = Set<String>()
        
        for entry in typedSources {
            // Add the core word (e.g., "ghost")
            uniqueSet.insert(entry.text.lowercased())
            
            // Harvest all hidden words from its rhyme package (e.g., "coast", "boast")
            for rhyme in entry.rhymes {
                let cleanRhyme = rhyme.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if !cleanRhyme.isEmpty {
                    uniqueSet.insert(cleanRhyme)
                }
            }
        }
        
        return Array(uniqueSet).shuffled()
    }
    
    /// Safely cleans up string variations and pulls corresponding rhymes
    static func getRhymes(for word: String) -> [String] {
        let cleanWord = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if it's a primary key word
        if let directMatch = words.first(where: { $0.text == cleanWord }) {
            return directMatch.rhymes.shuffled()
        }
        
        // 🚀 NEW SETUP ADDITION: Reverse lookup! If the user clicks a harvested word,
        // find the master group it belonged to so it STILL rhymes perfectly in rhyme mode.
        if let reverseMatch = words.first(where: { $0.rhymes.contains(cleanWord) }) {
            var completeFamily = reverseMatch.rhymes
            completeFamily.append(reverseMatch.text)
            completeFamily.removeAll(where: { $0.lowercased() == cleanWord })
            return completeFamily.shuffled()
        }
        
        return genericRhymes.shuffled()
    }
    
    /// Looks up an explicit structural word entry by key string
    static func findWord(_ keyword: String) -> WordMetadata {
        let clean = keyword.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if let primary = words.first(where: { $0.text == clean }) {
            return primary
        }
        
        // Reverse structure match fallback
        if let reverse = words.first(where: { $0.rhymes.contains(clean) }) {
            return WordMetadata(text: clean, type: reverse.type, rhymes: reverse.rhymes)
        }
        
        return WordMetadata(
            text: "flow",
            type: .noun,
            rhymes: genericRhymes
        )
    }
}
