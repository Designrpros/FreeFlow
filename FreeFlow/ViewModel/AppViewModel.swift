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
    private let kUseManualAnchor = "ff_use_manual_anchor"
    private let kCanvasColor = "ff_canvas_color"
    private let kAppAccent = "ff_app_accent"

    init() {}
    
    // 🚀 ECOSYSTEM INITIALIZATION MECHANISM: Pre-warms components while splash displays
    @MainActor
    func prepareAppEcosystem(settings: FlowSettings) async {
        // 0. Activate audio engine so it's fully ready before any playback
        AudioManager.shared.prepareEngine()
        
        // 1. Synchronously compile available tracks inside document rosters
        settings.refreshTracksRoster()
        
        // 2. Load CoreData context to prevent disk access hitching on load
        _ = PersistenceController.shared
        
        // 3. Keep splash active for 1.2 seconds so everything finishes configuring smoothly
        try? await Task.sleep(nanoseconds: 1_200_000_000)
        
        // 4. Dismiss splash screen and display the app
        self.hasFinishedSplash = true
    }
    
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
            settings.numberOfWords = 4
        }
        
        let savedInterval = defaults.double(forKey: kRefreshInterval)
        if savedInterval > 0 {
            settings.refreshInterval = savedInterval
        }
        
        if let savedTrack = defaults.string(forKey: kSelectedTrack) {
            settings.selectedTrack = savedTrack
        }
        
        if defaults.object(forKey: kPreventScreenLock) != nil {
            settings.preventScreenLock = defaults.bool(forKey: kPreventScreenLock)
        }
        if defaults.object(forKey: kLoopWithCrossfade) != nil {
            settings.loopWithCrossfade = defaults.bool(forKey: kLoopWithCrossfade)
        }
        if defaults.object(forKey: kUseManualAnchor) != nil {
            settings.useManualAnchor = defaults.bool(forKey: kUseManualAnchor)
        }
        
        if let rawBehavior = defaults.string(forKey: kEndBehavior), let behavior = PlaybackEndBehavior(rawValue: rawBehavior) {
            settings.endBehavior = behavior
        }
        if let rawTheme = defaults.string(forKey: kAppTheme), let theme = AppTheme(rawValue: rawTheme) {
            settings.appTheme = theme
        }
        if let rawCanvas = defaults.string(forKey: kCanvasColor), let canvas = CanvasColor(rawValue: rawCanvas) {
            settings.canvasColor = canvas
        }
        if let rawAccent = defaults.string(forKey: kAppAccent), let accent = AppAccent(rawValue: rawAccent) {
            settings.appAccent = accent
        }
    }
    
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
        defaults.set(settings.useManualAnchor, forKey: kUseManualAnchor)
        defaults.set(settings.endBehavior.rawValue, forKey: kEndBehavior)
        defaults.set(settings.appTheme.rawValue, forKey: kAppTheme)
        defaults.set(settings.canvasColor.rawValue, forKey: kCanvasColor)
        defaults.set(settings.appAccent.rawValue, forKey: kAppAccent)
    }
}
