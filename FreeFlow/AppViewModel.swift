//
//  AppViewModel.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 20/05/2026.
//

import Foundation
import Combine

final class AppViewModel: ObservableObject {
    @Published var hasFinishedSplash: Bool = false
    
    // --- LOCAL STORAGE KEYS ---
    private let kFreestyleMode = "ff_freestyle_mode"
    private let kRefreshStyle = "ff_refresh_style"
    private let kWordSource = "ff_word_source"
    private let kNumberOfWords = "ff_number_of_words"
    private let kRefreshInterval = "ff_refresh_interval"
    private let kSelectedTrack = "ff_selected_track"
    private let kPreventScreenLock = "ff_prevent_screen_lock"
    private let kLoopWithCrossfade = "ff_loop_with_crossfade"
    private let kEndBehavior = "ff_end_behavior"
    private let kAppTheme = "ff_app_theme"
    // FIXED: Appended storage key key token for the manual anchor switch flag state
    private let kUseManualAnchor = "ff_use_manual_anchor"

    init() {
        // AppViewModel can remain an active global lifecycle hook if needed
    }
    
    /// Pulls saved values out of UserDefaults disk storage and applies them directly into your runtime configurations
    func loadSavedSettings(into settings: FlowSettings) {
        let defaults = UserDefaults.standard
        
        if let rawMode = defaults.string(forKey: kFreestyleMode), let mode = FreestyleMode(rawValue: rawMode) {
            settings.freestyleMode = mode
        }
        if let rawStyle = defaults.string(forKey: kRefreshStyle), let style = RefreshStyle(rawValue: rawStyle) {
            settings.refreshStyle = style
        }
        if let rawSource = defaults.string(forKey: kWordSource), let source = WordSource(rawValue: rawSource) {
            settings.wordSource = source
        }
        
        let savedCount = defaults.integer(forKey: kNumberOfWords)
        if savedCount >= 1 && savedCount <= 6 {
            settings.numberOfWords = savedCount
        } else {
            settings.numberOfWords = 4 // Baseline safe layout target default
        }
        
        let savedInterval = defaults.double(forKey: kRefreshInterval)
        if savedInterval > 0 {
            settings.refreshInterval = savedInterval
        }
        
        if let savedTrack = defaults.string(forKey: kSelectedTrack) {
            settings.selectedTrack = savedTrack
        }
        
        // Booleans fallback cleanly to false if unwritten, so we explicit check registration presence
        if defaults.object(forKey: kPreventScreenLock) != nil {
            settings.preventScreenLock = defaults.bool(forKey: kPreventScreenLock)
        }
        if defaults.object(forKey: kLoopWithCrossfade) != nil {
            settings.loopWithCrossfade = defaults.bool(forKey: kLoopWithCrossfade)
        }
        
        // FIXED: Hydrates the new manual target switch state properly from disc references
        if defaults.object(forKey: kUseManualAnchor) != nil {
            settings.useManualAnchor = defaults.bool(forKey: kUseManualAnchor)
        }
        
        if let rawBehavior = defaults.string(forKey: kEndBehavior), let behavior = PlaybackEndBehavior(rawValue: rawBehavior) {
            settings.endBehavior = behavior
        }
        if let rawTheme = defaults.string(forKey: kAppTheme), let theme = AppTheme(rawValue: rawTheme) {
            settings.appTheme = theme
        }
    }
    
    /// Commits active user alterations directly down to the device disk space
    func saveSettings(from settings: FlowSettings) {
        let defaults = UserDefaults.standard
        
        defaults.set(settings.freestyleMode.rawValue, forKey: kFreestyleMode)
        defaults.set(settings.refreshStyle.rawValue, forKey: kRefreshStyle)
        defaults.set(settings.wordSource.rawValue, forKey: kWordSource)
        defaults.set(settings.numberOfWords, forKey: kNumberOfWords)
        defaults.set(settings.refreshInterval, forKey: kRefreshInterval)
        defaults.set(settings.selectedTrack, forKey: kSelectedTrack)
        defaults.set(settings.preventScreenLock, forKey: kPreventScreenLock)
        defaults.set(settings.loopWithCrossfade, forKey: kLoopWithCrossfade)
        // FIXED: Persists toggle positions continuously into disk slots on changes
        defaults.set(settings.useManualAnchor, forKey: kUseManualAnchor)
        defaults.set(settings.endBehavior.rawValue, forKey: kEndBehavior)
        defaults.set(settings.appTheme.rawValue, forKey: kAppTheme)
    }
}
