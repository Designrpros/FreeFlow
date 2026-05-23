//
//  WordsRepository.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 20/05/2026.
//

import Foundation

protocol WordsRepository {
    func initialWords(count: Int) -> [String]
    func randomWords(count: Int) -> [String]
    // 🚀 FIXED: Added a strict boolean toggle to separate logic explicitly
    func rhymeWords(count: Int, focusingOn focusWord: String?, useRhymeMode: Bool) async -> [String]
}

struct StaticWordsRepository: WordsRepository {
    
    func initialWords(count: Int) -> [String] {
        return Array(RhymesDatabase.allUniqueWords(for: .noun).prefix(max(0, count)))
    }

    /// 🚀 MODE 1: Standard Keywords (True Random Generator)
    /// Pops an unpredictable mix of non-rhyming nouns, verbs, adjectives, and adverbs.
    func randomWords(count: Int) -> [String] {
        let targetCount = max(0, count)
        guard targetCount > 0 else { return [] }
        
        var selectedWords: [String] = []
        
        var nouns = RhymesDatabase.allUniqueWords(for: .noun)
        var verbs = RhymesDatabase.allUniqueWords(for: .verb)
        var adjectives = RhymesDatabase.allUniqueWords(for: .adjective)
        var adverbs = RhymesDatabase.allUniqueWords(for: .adverb)
        
        for i in 0..<targetCount {
            let cycleIndex = i % 4
            var pickedWord: String? = nil
            
            switch cycleIndex {
            case 0: pickedWord = nouns.popLast()
            case 1: pickedWord = verbs.popLast()
            case 2: pickedWord = adjectives.popLast()
            default: pickedWord = adverbs.popLast()
            }
            
            if let word = pickedWord {
                selectedWords.append(word.lowercased())
            }
        }
        
        return Array(selectedWords.prefix(targetCount))
    }
    
    /// 🚀 THE DYNAMIC APIS CONTROLLER
    /// Guarantees that Standard Mode returns pure random words, while Rhyme Mode utilizes strict rel_rhy queries.
    func rhymeWords(count: Int, focusingOn focusWord: String? = nil, useRhymeMode: Bool) async -> [String] {
        let targetCount = max(1, count)
        
        // 🛑 DIRECT ROUTING GATING: If Rhyme mode is false, it means Standard Keywords is toggled.
        // Instantly bypass all Datamuse rhyme queries and deliver a pure non-rhyming random shuffle!
        if !useRhymeMode {
            print("🎲 [WordsRepository] Standard Mode selected. Returning pure random word loop matrix.")
            return randomWords(count: targetCount)
        }
        
        // --- OTHERWISE EXECUTE STRICT PERFECT PHONETIC RHYMING PASS ---
        let cleanInput = focusWord?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let activeFocusWord: String
        
        if !cleanInput.isEmpty {
            activeFocusWord = cleanInput
        } else {
            guard let randomDbWord = RhymesDatabase.words.shuffled().first?.text else { return [] }
            activeFocusWord = randomDbWord
        }
        
        var structuralChain: [String] = [activeFocusWord.lowercased()]
        print("🎯 [WordsRepository] Word Flow + Rhymes Active. Fetching strict rhymes for: \(activeFocusWord)")
        
        // Query strict phonetic end rhymes via Datamuse rel_rhy endpoint
        let liveDataResults = await DatamuseAPI.shared.fetchRhymes(for: activeFocusWord)
        var liveRhymes = liveDataResults.map { $0.word }
        
        // Filter anchor duplicates
        liveRhymes.removeAll(where: { $0.lowercased() == activeFocusWord.lowercased() })
        
        // Clean multi-word phrase anomalies returned by the server (e.g. "around lee")
        liveRhymes = liveRhymes.filter { word in
            let components = word.components(separatedBy: .whitespacesAndNewlines)
            return components.count == 1 && !word.contains("-")
        }
        
        while structuralChain.count < targetCount && !liveRhymes.isEmpty {
            structuralChain.append(liveRhymes.removeFirst().lowercased())
        }
        
        // Local DB Fallback (Using your raw database files)
        if structuralChain.count < targetCount {
            let cleanFocus = activeFocusWord.lowercased()
            
            if let localMatch = RhymesDatabase.words.first(where: { $0.text.lowercased() == cleanFocus }) {
                var localRhymes = localMatch.rhymes.shuffled()
                localRhymes.removeAll(where: { structuralChain.contains($0.lowercased()) })
                while structuralChain.count < targetCount && !localRhymes.isEmpty {
                    structuralChain.append(localRhymes.removeLast().lowercased())
                }
            } else if let reverseMatch = RhymesDatabase.words.first(where: { $0.rhymes.contains(cleanFocus) }) {
                var localRhymes = reverseMatch.rhymes.shuffled()
                localRhymes.append(reverseMatch.text)
                localRhymes.removeAll(where: { $0.lowercased() == cleanFocus || structuralChain.contains($0.lowercased()) })
                while structuralChain.count < targetCount && !localRhymes.isEmpty {
                    structuralChain.append(localRhymes.removeLast().lowercased())
                }
            }
        }
        
        // Generic end-cap fallbacks
        if structuralChain.count < targetCount {
            var genericFallbacks = RhymesDatabase.genericRhymes.shuffled()
            genericFallbacks.removeAll(where: { structuralChain.contains($0.lowercased()) })
            while structuralChain.count < targetCount && !genericFallbacks.isEmpty {
                structuralChain.append(genericFallbacks.removeLast().lowercased())
            }
        }
        
        return Array(structuralChain.prefix(targetCount))
    }
}
