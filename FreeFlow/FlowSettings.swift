//
//  FlowSettings.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 21/05/2026.
//

import Combine
import SwiftUI

enum FreestyleMode: String, CaseIterable, Identifiable {
    case standardKeywords = "Standard Keywords"
    case wordFlowPlusRhymes = "Word Flow + Rhymes"
    var id: String { rawValue }
}

enum RefreshStyle: String, CaseIterable, Identifiable {
    case manualTap = "Manual (Tap)"
    case auto = "Automatic"
    var id: String { rawValue }
}

enum WordSource: String, CaseIterable, Identifiable {
    case staticLibrary = "Static Library"
    case datamuseAPI = "Datamuse API"
    var id: String { rawValue }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    var id: String { rawValue }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum PlaybackEndBehavior: String, CaseIterable, Identifiable {
    case loopTrack = "Loop Track"
    case nextTrack = "Next Track"
    var id: String { rawValue }
}

final class FlowSettings: ObservableObject {
    @Published var freestyleMode: FreestyleMode = .standardKeywords
    @Published var refreshStyle: RefreshStyle = .manualTap
    @Published var wordSource: WordSource = .staticLibrary

    @Published var showAdvanced: Bool = false
    @Published var appTheme: AppTheme = .system
    @Published var preventScreenLock: Bool = true
    @Published var loopWithCrossfade: Bool = true
    
    @Published var selectedTrack: String = "Chrome_On_The_Curb"
    @Published var endBehavior: PlaybackEndBehavior = .loopTrack
    
    @Published var customFocusWord: String = ""

    @Published var refreshInterval: Double = 10.0

    @Published var availableTracks: [String] = []
    
    @Published var numberOfWords: Int = 4 {
        didSet {
            if numberOfWords < 1 { numberOfWords = 1 }
            if numberOfWords > 6 { numberOfWords = 6 }
        }
    }
    
    let factoryTracks: [String] = [
        "Chrome_On_The_Curb", "JazzyFlow", "JazzyFlowDeep", "Late_August_Porch",
        "Low_Rider_Glide", "Morning_on_the_Deck", "Passing_Thru_Willow_Street", "Under_The_Surface"
    ]
    
    // Memory retain handling structures for the Combine observation subscription closure
    private let appViewModel = AppViewModel()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        refreshTracksRoster()
        
        // 1. Instantly pull previously saved state from local storage disk space on class initialization
        appViewModel.loadSavedSettings(into: self)
        
        // 2. Monitor changes to internal configurations and write updates to storage on the next loop tick
        self.objectWillChange
            .sink { [weak self] _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.appViewModel.saveSettings(from: self)
                }
            }
            .store(in: &cancellables)
    }
    
    func refreshTracksRoster() {
        self.availableTracks = factoryTracks
    }
}
