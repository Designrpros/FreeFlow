//
//  FlowViewModel.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 22/05/2026.
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
        let isUsingAPI = (settings.wordSource == .datamuseAPI)
        
        if isUsingAPI {
            // ONLINE API MODE: Engage the asynchronous workflow with loading indicators
            isLoading = true
            
            Task {
                let fetchedWords: [String]
                
                if settings.freestyleMode == .wordFlowPlusRhymes {
                    let anchor: String?
                    if settings.useManualAnchor && !settings.customFocusWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        anchor = settings.customFocusWord
                    } else {
                        anchor = nil
                    }
                    
                    fetchedWords = await repo.rhymeWords(count: settings.numberOfWords, focusingOn: anchor)
                    
                    if anchor == nil, settings.useManualAnchor, let firstWord = fetchedWords.first {
                        settings.customFocusWord = firstWord
                    }
                } else {
                    // Standard Keywords API Mode -> Use Datamuse for random/related streams
                    fetchedWords = await repo.rhymeWords(count: settings.numberOfWords, focusingOn: nil)
                }
                
                self.words = fetchedWords
                self.isLoading = false
            }
        } else {
            // OFFLINE MODE (Static Library): Execute instantly with zero loading states or delayed async steps
            isLoading = false
            
            if settings.freestyleMode == .wordFlowPlusRhymes {
                let anchor: String?
                if settings.useManualAnchor && !settings.customFocusWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    anchor = settings.customFocusWord
                } else {
                    anchor = nil
                }
                
                Task {
                    let fetchedWords = await repo.rhymeWords(count: settings.numberOfWords, focusingOn: anchor)
                    
                    if anchor == nil, settings.useManualAnchor, let firstWord = fetchedWords.first {
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
