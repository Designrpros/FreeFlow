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
    // Marked async to allow for the Datamuse HTTP request network layer
    func rhymeWords(count: Int, focusingOn focusWord: String?) async -> [String]
}

struct StaticWordsRepository: WordsRepository {
    
    func initialWords(count: Int) -> [String] {
        return Array(RhymesDatabase.words.map { $0.text }.prefix(max(0, count)))
    }

    /// Pulls a balanced syntax chain using Word Type theory (Normal Mode)
    func randomWords(count: Int) -> [String] {
        let targetCount = max(0, count)
        guard targetCount > 0 else { return [] }
        
        var selectedWords: [String] = []
        
        var nouns = RhymesDatabase.words.filter { $0.type == .noun }.shuffled()
        var verbs = RhymesDatabase.words.filter { $0.type == .verb }.shuffled()
        var adjectives = RhymesDatabase.words.filter { $0.type == .adjective }.shuffled()
        var adverbs = RhymesDatabase.words.filter { $0.type == .adverb }.shuffled()
        
        for i in 0..<targetCount {
            let cycleIndex = i % 4
            var pickedWord: String? = nil
            
            switch cycleIndex {
            case 0: pickedWord = nouns.popLast()?.text
            case 1: pickedWord = verbs.popLast()?.text
            case 2: pickedWord = adjectives.popLast()?.text
            default: pickedWord = adverbs.popLast()?.text
            }
            
            if let word = pickedWord {
                selectedWords.append(word)
            }
        }
        
        if selectedWords.count < targetCount {
            var fallbackExtras = RhymesDatabase.words.map { $0.text }.shuffled()
            while selectedWords.count < targetCount && !fallbackExtras.isEmpty {
                if let fallbackWord = fallbackExtras.popLast() {
                    if !selectedWords.contains(fallbackWord) {
                        selectedWords.append(fallbackWord)
                    }
                }
            }
        }
        
        return Array(selectedWords.prefix(targetCount))
    }
    
    /// Focus Word / Rhyme Mode: Leverages live Datamuse API data with native offline fallbacks
    func rhymeWords(count: Int, focusingOn focusWord: String? = nil) async -> [String] {
        let targetCount = max(1, count)
        
        // 1. Determine the focus word: Use the passed input string, or select a random fallback from DB
        let activeFocusWord: String
        if let userProvidedWord = focusWord, !userProvidedWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            activeFocusWord = userProvidedWord
        } else {
            guard let randomDbWord = RhymesDatabase.words.shuffled().first?.text else { return [] }
            activeFocusWord = randomDbWord
        }
        
        var structuralChain: [String] = [activeFocusWord]
        
        // FIXED: Query Datamuse using the unified API coordinator and map the model instances to raw string values
        let liveDataResults = await DatamuseAPI.shared.fetchRhymes(for: activeFocusWord)
        var liveRhymes = liveDataResults.map { $0.word }
        
        // Safety strip-out of the core focus word from results
        liveRhymes.removeAll(where: { $0.lowercased() == activeFocusWord.lowercased() })
        
        // 3. Populate structural chain with live API rhymes
        while structuralChain.count < targetCount && !liveRhymes.isEmpty {
            structuralChain.append(liveRhymes.removeFirst())
        }
        
        // 4. Local DB Fallback (If offline or if Datamuse API returns fewer results than requested count)
        if structuralChain.count < targetCount {
            // Check if our local database matches the focus word to pull predefined rhymes
            if let localMatch = RhymesDatabase.words.first(where: { $0.text.lowercased() == activeFocusWord.lowercased() }) {
                var localRhymes = localMatch.rhymes.shuffled()
                localRhymes.removeAll(where: { structuralChain.contains($0.lowercased()) })
                
                while structuralChain.count < targetCount && !localRhymes.isEmpty {
                    structuralChain.append(localRhymes.removeLast())
                }
            }
        }
        
        // 5. Ultimate Emergency Fallback (Generic rhymes bucket)
        if structuralChain.count < targetCount {
            var genericFallbacks = RhymesDatabase.genericRhymes.shuffled()
            genericFallbacks.removeAll(where: { structuralChain.contains($0.lowercased()) })
            
            while structuralChain.count < targetCount && !genericFallbacks.isEmpty {
                structuralChain.append(genericFallbacks.removeLast())
            }
        }
        
        return Array(structuralChain.prefix(targetCount))
    }
}
