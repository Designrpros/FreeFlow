//
//  FlowSettings.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 23/05/2026.
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

enum CanvasColor: String, CaseIterable, Identifiable {
    case defaultGray = "Default"
    case monochrome = "Monochrome"
    case ember = "Ember"
    case oceanic = "Oceanic"
    case midnight = "Midnight"
    var id: String { rawValue }
    
    func backgroundColor(isDark: Bool) -> Color {
        switch self {
        case .defaultGray: return isDark ? Color(white: 0.12) : Color(white: 0.95)
        case .monochrome:  return isDark ? Color(white: 0.05) : Color(white: 1.0)
        case .ember:       return isDark ? Color(red: 0.25, green: 0.11, blue: 0.04) : Color(red: 0.96, green: 0.91, blue: 0.86)
        case .oceanic:     return isDark ? Color(red: 0.09, green: 0.20, blue: 0.17) : Color(red: 0.88, green: 0.94, blue: 0.92)
        case .midnight:    return isDark ? Color(red: 0.10, green: 0.09, blue: 0.18) : Color(red: 0.91, green: 0.90, blue: 0.96)
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
    @Published var freestyleMode: FreestyleMode = .standardKeywords { didSet { saveTrigger.send() } }
    @Published var refreshStyle: RefreshStyle = .manualTap { didSet { saveTrigger.send() } }
    @Published var wordSource: WordSource = .staticLibrary { didSet { saveTrigger.send() } }
    @Published var showAdvanced: Bool = false
    
    @Published var appTheme: AppTheme = .system {
        didSet {
            saveTrigger.send()
            DispatchQueue.main.async { self.applyInterfaceThemeOverride() }
        }
    }
    
    @Published var canvasColor: CanvasColor = .defaultGray { didSet { saveTrigger.send() } }
    @Published var appAccent: AppAccent = .defaultBlue { didSet { saveTrigger.send() } }
    @Published var preventScreenLock: Bool = true { didSet { saveTrigger.send() } }
    @Published var loopWithCrossfade: Bool = true { didSet { saveTrigger.send() } }
    @Published var selectedTrack: String = "Chrome_On_The_Curb.mp3" { didSet { saveTrigger.send() } }
    @Published var endBehavior: PlaybackEndBehavior = .loopTrack { didSet { saveTrigger.send() } }
    @Published var customFocusWord: String = ""
    @Published var useManualAnchor: Bool = false { didSet { saveTrigger.send() } }
    @Published var refreshInterval: Double = 10.0 { didSet { saveTrigger.send() } }
    @Published var availableTracks: [String] = []
    
    @Published var numberOfWords: Int = 4 {
        didSet {
            if numberOfWords < 1 { numberOfWords = 1 }
            if numberOfWords > 6 { numberOfWords = 6 }
            saveTrigger.send()
        }
    }
    
    @Published var isRecordingSession: Bool = false
    @Published var recordingDuration: TimeInterval = 0.0
    
    @Published var playbackSpeed: Double = 1.0 {
        didSet {
            if playbackSpeed < 0.5 { playbackSpeed = 0.5 }
            if playbackSpeed > 2.0 { playbackSpeed = 2.0 }
            saveTrigger.send()
        }
    }
    @Published var pitchShiftSemitones: Int = 0 {
        didSet {
            if pitchShiftSemitones < -12 { pitchShiftSemitones = -12 }
            if pitchShiftSemitones > 12 { pitchShiftSemitones = 12 }
            saveTrigger.send()
        }
    }
    @Published var crossfadeDuration: Double = 1.0 {
        didSet {
            if crossfadeDuration < 0.1 { crossfadeDuration = 0.1 }
            if crossfadeDuration > 5.0 { crossfadeDuration = 5.0 }
            saveTrigger.send()
        }
    }
    @Published var enableMicMonitor: Bool = false { didSet { saveTrigger.send() } }
    @Published var trackDownloadStates: [String: TrackDownloadState] = [:]

    enum TrackDownloadState {
        case idle
        case downloading
        case ready
    }
    
    let factoryTracks: [String] = [
        "Chrome_On_The_Curb.mp3", "JazzyFlow.mp3", "JazzyFlowDeep.mp3", "Late_August_Porch.mp3",
        "Low_Rider_Glide.mp3", "Morning_on_the_Deck.mp3", "Passing_Thru_Willow_Street.mp3", "Under_The_Surface.mp3"
    ]
    
    var instrumentalBackingTracks: [String] {
        availableTracks.filter { !$0.hasPrefix("FreeFlow_Session_") }
    }
    
    private let saveTrigger = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.availableTracks = factoryTracks
        
        // ✅ FIXED: Routed parameters context through clear static utility functions
        AppViewModel.loadSavedSettings(into: self)
        
        sanitizeSelectedTrackExtension()
        refreshTracksRoster()
        
        DispatchQueue.main.async {
            self.applyInterfaceThemeOverride()
        }
        
        saveTrigger
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                // ✅ FIXED: References data serializations strictly via static memory map spaces
                AppViewModel.saveSettings(from: self)
            }
            .store(in: &cancellables)
    }
    
    private func sanitizeSelectedTrackExtension() {
        let trimmed = selectedTrack.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix(".mp3") || trimmed.hasSuffix(".m4a") { return }
        
        let lowercased = trimmed.lowercased()
        if lowercased.contains("chrome") { selectedTrack = "Chrome_On_The_Curb.mp3" }
        else if lowercased.contains("jazzyflowdeep") { selectedTrack = "JazzyFlowDeep.mp3" }
        else if lowercased.contains("jazzyflow") { selectedTrack = "JazzyFlow.mp3" }
        else if lowercased.contains("late_august") { selectedTrack = "Late_August_Porch.mp3" }
        else if lowercased.contains("low_rider") { selectedTrack = "Low_Rider_Glide.mp3" }
        else if lowercased.contains("morning") { selectedTrack = "Morning_on_the_Deck.mp3" }
        else if lowercased.contains("passing") { selectedTrack = "Passing_Thru_Willow_Street.mp3" }
        else if lowercased.contains("under") { selectedTrack = "Under_The_Surface.mp3" }
        else { selectedTrack = "\(trimmed).mp3" }
    }
    
    func refreshTracksRoster() {
        var updatedTracks = factoryTracks
        let targetDirectory: URL
        if let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") {
            targetDirectory = iCloudURL
        } else {
            targetDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        }
        
        do {
            if !FileManager.default.fileExists(atPath: targetDirectory.path) {
                try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)
            }
            let fileURLs = try FileManager.default.contentsOfDirectory(at: targetDirectory, includingPropertiesForKeys: nil)
            let customTracks = fileURLs
                .filter { $0.pathExtension == "m4a" || $0.pathExtension == "mp3" }
                .map { $0.lastPathComponent }
                .sorted()
            updatedTracks.append(contentsOf: customTracks)
        } catch {
            print("⚠️ [FlowSettings] Failed to scan disk container folder: \(error.localizedDescription)")
        }
        
        sanitizeSelectedTrackExtension()
        
        let backingTracks = updatedTracks.filter { !$0.hasPrefix("FreeFlow_Session_") }
        if !backingTracks.contains(selectedTrack) {
            let baseWithoutExtension = selectedTrack.replacingOccurrences(of: ".mp3", with: "").replacingOccurrences(of: ".m4a", with: "")
            if let matchedWithExtension = backingTracks.first(where: { $0.localizedCaseInsensitiveContains(baseWithoutExtension) }) {
                selectedTrack = matchedWithExtension
            } else {
                selectedTrack = "Chrome_On_The_Curb.mp3"
            }
        }
        
        self.availableTracks = updatedTracks
    }

    func downloadCloudTrackOnDemand(_ filename: String) {
        guard trackDownloadStates[filename] != .downloading else { return }
        print("🔊 [FlowSettings] Initiating native system download hook for cloud asset: \(filename)")
        
        DispatchQueue.main.async { self.trackDownloadStates[filename] = .downloading }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let targetURL = LocalStorageManager.shared.resolveAbsoluteLocalURL(for: filename)
            let strippedName = filename.replacingOccurrences(of: ".mp3", with: "").replacingOccurrences(of: ".m4a", with: "")
            let alternateURL = LocalStorageManager.shared.resolveAbsoluteLocalURL(for: strippedName)
            let finalDownloadURL = FileManager.default.fileExists(atPath: alternateURL.path) ? alternateURL : targetURL
            
            try? FileManager.default.startDownloadingUbiquitousItem(at: finalDownloadURL)
            
            var downloadComplete = false
            var attempts = 0
            let maxAttempts = 120
            
            while !downloadComplete && attempts < maxAttempts {
                if LocalStorageManager.shared.isLocalFileReady(fileName: filename) ||
                   LocalStorageManager.shared.isLocalFileReady(fileName: strippedName) {
                    downloadComplete = true
                } else {
                    attempts += 1
                    Thread.sleep(forTimeInterval: 0.5)
                }
            }
            
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if downloadComplete {
                        self.trackDownloadStates[filename] = .ready
                        self.refreshTracksRoster()
                        if self.selectedTrack == filename && !AudioManager.shared.isPlaying {
                            AudioManager.shared.play(trackName: filename, using: self)
                        }
                    } else {
                        self.trackDownloadStates[filename] = .idle
                    }
                }
            }
        }
    }
    
    private func applyInterfaceThemeOverride() {
        #if os(iOS)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        for window in windowScene.windows {
            switch appTheme {
            case .system: window.overrideUserInterfaceStyle = .unspecified
            case .light:  window.overrideUserInterfaceStyle = .light
            case .dark:   window.overrideUserInterfaceStyle = .dark
            }
        }
        #elseif os(macOS)
        switch appTheme {
        case .system: NSApp.appearance = nil
        case .light:  NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:   NSApp.appearance = NSAppearance(named: .darkAqua)
        }
        #endif
    }
}
