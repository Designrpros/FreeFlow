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
    private var autoRefreshTask: Task<Void, Never>? = nil
    
    // Combine storage pointer to observe settings context continuously
    private var settingsCancellables = Set<AnyCancellable>()

    /// Actor-isolated initializer safely handling dependency injection boundaries
    init(repo: WordsRepository? = nil) {
        self.repo = repo ?? StaticWordsRepository()
    }

    /// Evaluates if data loading is required upon view layout mount
    func ensureInitialized(using settings: FlowSettings) {
        if words.isEmpty {
            refresh(using: settings)
        }
        
        // 🚀 FIXED: Bind our auto-refresh engine explicitly to changes inside FlowSettings
        observeSettingsEcosystem(settings)
    }
    
    private func observeSettingsEcosystem(_ settings: FlowSettings) {
        settingsCancellables.removeAll()
        
        // Listen to BOTH style updates and timing intervals simultaneously
        Publishers.CombineLatest(settings.$refreshStyle, settings.$refreshInterval)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] style, interval in
                guard let self = self else { return }
                if style == .auto {
                    self.startAutoRefreshEngine(interval: interval, settings: settings)
                } else {
                    self.terminateEcosystemEngine()
                }
            }
            .store(in: &settingsCancellables)
    }

    /// Handles shuffling/fetching states smoothly depending on whether the source is local or network-reliant
    func refresh(using settings: FlowSettings) {
        let isUsingAPI = (settings.wordSource == .datamuseAPI)
        
        if isUsingAPI {
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
                    fetchedWords = await repo.rhymeWords(count: settings.numberOfWords, focusingOn: nil)
                }
                
                self.words = fetchedWords
                self.isLoading = false
            }
        } else {
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
                self.words = repo.randomWords(count: settings.numberOfWords)
            }
        }
    }
    
    // 🚀 FIXED: Background asynchronous loop decoupled completely from thread-blocked publishers
    private func startAutoRefreshEngine(interval: Double, settings: FlowSettings) {
        autoRefreshTask?.cancel()
        
        autoRefreshTask = Task {
            while !Task.isCancelled {
                let nanosecondsDelay = UInt64(interval * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanosecondsDelay)
                
                // Double check cancellation status before committing layout jumps
                guard !Task.isCancelled else { break }
                
                self.refresh(using: settings)
            }
        }
    }
    
    func terminateEcosystemEngine() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }
}
