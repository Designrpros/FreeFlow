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

// FIXED: Restored to standard system interface overrides
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

// FIXED: Created a distinct property layer managing background color signatures independently
enum CanvasColor: String, CaseIterable, Identifiable {
    case defaultGray = "Default"
    case monochrome = "Monochrome"
    case ember = "Ember"
    case oceanic = "Oceanic"
    case midnight = "Midnight"
    
    var id: String { rawValue }
    
    func backgroundColor(isDark: Bool) -> Color {
        switch self {
        case .defaultGray:
            return isDark ? Color(white: 0.12) : Color(white: 0.95)
        case .monochrome:
            return isDark ? Color(white: 0.05) : Color(white: 1.0)
        case .ember:
            return isDark ? Color(red: 0.25, green: 0.11, blue: 0.04) : Color(red: 0.96, green: 0.91, blue: 0.86)
        case .oceanic:
            return isDark ? Color(red: 0.09, green: 0.20, blue: 0.17) : Color(red: 0.88, green: 0.94, blue: 0.92)
        case .midnight:
            return isDark ? Color(red: 0.10, green: 0.09, blue: 0.18) : Color(red: 0.91, green: 0.90, blue: 0.96)
        }
    }
}

enum AppAccent: String, CaseIterable, Identifiable {
    case defaultBlue = "Default"
    case monochrome = "Monochrome"
    case ember = "Ember"
    case oceanic = "Oceanic"
    case midnight = "Midnight"
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .defaultBlue: return .blue
        case .monochrome:  return .primary
        case .ember:       return .orange
        case .oceanic:     return .teal
        case .midnight:    return .purple
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
    @Published var canvasColor: CanvasColor = .defaultGray
    @Published var appAccent: AppAccent = .defaultBlue
    
    @Published var preventScreenLock: Bool = true
    @Published var loopWithCrossfade: Bool = true
    
    @Published var selectedTrack: String = "Chrome_On_The_Curb"
    @Published var endBehavior: PlaybackEndBehavior = .loopTrack
    
    @Published var customFocusWord: String = ""
    @Published var useManualAnchor: Bool = false

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
    
    private let appViewModel = AppViewModel()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        refreshTracksRoster()
        appViewModel.loadSavedSettings(into: self)
        
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
