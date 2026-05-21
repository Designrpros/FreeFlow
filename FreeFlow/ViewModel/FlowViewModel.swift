//
//  FlowViewModel.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 20/05/2026.
//

import Foundation
import Combine

@MainActor
final class FlowViewModel: ObservableObject {
    @Published private(set) var words: [String] = []
    @Published var isLoading: Bool = false
    
    private let repo: WordsRepository

    /// Actor-isolated initializer safely handling dependency injection boundaries
    init(repo: WordsRepository? = nil) {
        self.repo = repo ?? StaticWordsRepository()
    }

    /// Evaluates if data loading is required upon view layout mount
    func ensureInitialized(using settings: FlowSettings) {
        if words.isEmpty {
            refresh(using: settings)
        }
    }

    /// Handles shuffling/fetching states smoothly depending on whether the source is local or network-reliant
    func refresh(using settings: FlowSettings) {
        // FIXED: The API is active whenever Datamuse API is selected as the Word Source
        let isUsingAPI = (settings.wordSource == .datamuseAPI)
        
        if isUsingAPI {
            // ONLINE API MODE: Engage the asynchronous workflow with loading indicators
            isLoading = true
            
            Task {
                let fetchedWords: [String]
                
                if settings.freestyleMode == .wordFlowPlusRhymes {
                    // 1. Focus Word API Mode -> Strict Rhymes from Datamuse
                    let anchor = settings.customFocusWord.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty ? nil : settings.customFocusWord
                    fetchedWords = await repo.rhymeWords(count: settings.numberOfWords, focusingOn: anchor)
                    
                    // Synchronize anchor text back to settings if a random one was generated
                    if anchor == nil, let firstWord = fetchedWords.first {
                        settings.customFocusWord = firstWord
                    }
                } else {
                    // 2. Standard Keywords API Mode -> Use Datamuse for random/related streams
                    // Fallback to random local words if you prefer standard mode completely local,
                    // or pass a default string to pull unique variations from Datamuse.
                    fetchedWords = await repo.rhymeWords(count: settings.numberOfWords, focusingOn: nil)
                }
                
                self.words = fetchedWords
                self.isLoading = false
            }
        } else {
            // OFFLINE MODE (Static Library): Execute instantly with zero loading states or delayed async steps
            isLoading = false
            
            if settings.freestyleMode == .wordFlowPlusRhymes {
                // Focus Word local mode (pulls entirely from your offline RhymesDatabase)
                let anchor = settings.customFocusWord.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty ? nil : settings.customFocusWord
                
                Task {
                    let fetchedWords = await repo.rhymeWords(count: settings.numberOfWords, focusingOn: anchor)
                    if anchor == nil, let firstWord = fetchedWords.first {
                        settings.customFocusWord = firstWord
                    }
                    self.words = fetchedWords
                }
            } else {
                // Standard mode: Balanced syntax generator sequence pulls completely synchronously
                self.words = repo.randomWords(count: settings.numberOfWords)
            }
        }
    }
}
