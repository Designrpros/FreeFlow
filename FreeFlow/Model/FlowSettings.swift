//
//  FlowSettings.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 22/05/2026.
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
    
    // FIXED: Appends a property observer to broadcast overrides to window instances instantly
    @Published var appTheme: AppTheme = .system {
        didSet {
            DispatchQueue.main.async {
                self.applyInterfaceThemeOverride()
            }
        }
    }
    
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
    
    @Published var isRecordingSession: Bool = false
    @Published var recordingDuration: TimeInterval = 0.0
    
    // PRO AUDIO LAYOUT CONTROLS
    @Published var playbackSpeed: Double = 1.0 {
        didSet {
            if playbackSpeed < 0.5 { playbackSpeed = 0.5 }
            if playbackSpeed > 2.0 { playbackSpeed = 2.0 }
        }
    }
    @Published var pitchShiftSemitones: Int = 0 {
        didSet {
            if pitchShiftSemitones < -12 { pitchShiftSemitones = -12 }
            if pitchShiftSemitones > 12 { pitchShiftSemitones = 12 }
        }
    }
    @Published var crossfadeDuration: Double = 1.0 {
        didSet {
            if crossfadeDuration < 0.1 { crossfadeDuration = 0.1 }
            if crossfadeDuration > 5.0 { crossfadeDuration = 5.0 }
        }
    }
    @Published var enableMicMonitor: Bool = false
    
    @Published var trackDownloadStates: [String: TrackDownloadState] = [:]

    enum TrackDownloadState {
        case idle
        case downloading
        case ready
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
        
        // FIXED: Re-verify system interface matching on initial startup configuration load
        DispatchQueue.main.async {
            self.applyInterfaceThemeOverride()
        }
        
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
        
        DispatchQueue.main.async {
            self.availableTracks = updatedTracks
        }
    }

    /// Robust, non-blocking asynchronous utility using system-native tracking to fetch cloud audio assets
    func downloadCloudTrackOnDemand(_ filename: String) {
        guard trackDownloadStates[filename] != .downloading else { return }
        
        print("🔊 [FlowSettings] Initiating native system download hook for cloud asset: \(filename)")
        
        DispatchQueue.main.async {
            self.trackDownloadStates[filename] = .downloading
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let targetURL = LocalStorageManager.shared.resolveAbsoluteLocalURL(for: filename)
            
            let strippedName = filename.replacingOccurrences(of: ".mp3", with: "").replacingOccurrences(of: ".m4a", with: "")
            let alternateURL = LocalStorageManager.shared.resolveAbsoluteLocalURL(for: strippedName)
            
            let finalDownloadURL = FileManager.default.fileExists(atPath: alternateURL.path) ? alternateURL : targetURL
            
            try? FileManager.default.startDownloadingUbiquitousItem(at: finalDownloadURL)
            
            var downloadComplete = false
            var attempts = 0
            let maxAttempts = 120 // 60 seconds total maximum time allocation budget
            
            while !downloadComplete && attempts < maxAttempts {
                if LocalStorageManager.shared.isLocalFileReady(fileName: filename) ||
                   LocalStorageManager.shared.isLocalFileReady(fileName: strippedName) ||
                   LocalStorageManager.shared.isLocalFileReady(fileName: finalDownloadURL.lastPathComponent) {
                    downloadComplete = true
                } else if let values = try? finalDownloadURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]),
                          values.ubiquitousItemDownloadingStatus == .current {
                    downloadComplete = true
                } else {
                    attempts += 1
                    Thread.sleep(forTimeInterval: 0.5)
                }
            }
            
            // FIXED: Isolate structural updates cleanly inside a main-thread boundary to prevent UI state freezups
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if downloadComplete {
                        print("🔊 [FlowSettings] Native check success for [\(filename)]. Refreshing UI layouts...")
                        self.trackDownloadStates[filename] = .ready
                        
                        // Safely trigger roster reconstruction on the main UI thread loop
                        self.refreshTracksRoster()
                        
                        if self.selectedTrack == filename && !AudioManager.shared.isPlaying {
                            AudioManager.shared.play(trackName: filename, using: self)
                        }
                    } else {
                        print("⚠️ [FlowSettings] Native verification timed out or file mismatch occurred for name string: \(filename)")
                        if FileManager.default.fileExists(atPath: finalDownloadURL.path) {
                            self.trackDownloadStates[filename] = .ready
                            self.refreshTracksRoster()
                        } else {
                            self.trackDownloadStates[filename] = .idle
                        }
                    }
                }
            }
        }
    }
    
    // FIXED: Multiplatform user interface layer renderer synchronization engine
    private func applyInterfaceThemeOverride() {
        #if os(iOS)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        for window in windowScene.windows {
            switch appTheme {
            case .system:
                window.overrideUserInterfaceStyle = .unspecified
            case .light:
                window.overrideUserInterfaceStyle = .light
            case .dark:
                window.overrideUserInterfaceStyle = .dark
            }
        }
        #elseif os(macOS)
        switch appTheme {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
        #endif
    }
}
