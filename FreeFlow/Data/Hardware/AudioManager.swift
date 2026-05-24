//
//  AudioManager.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 23/05/2026.
//

import Foundation
import AVFoundation
import Combine

final class AudioManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = AudioManager()
    
    // --- NATIVE ENGINE NODES ---
    private let audioEngine = AVAudioEngine()
    private let playerNodeA = AVAudioPlayerNode()
    private let timePitchNodeA = AVAudioUnitTimePitch()
    private let mixerA = AVAudioMixerNode()
    private let micMonitorMixer = AVAudioMixerNode()
    
    // --- FALLBACK SYSTEM ---
    private var fallbackPlayerA: AVAudioPlayer?
    private var fallbackPlayerB: AVAudioPlayer?
    private var useFallbackEngine = false
    
    private var settingsReference: FlowSettings?
    private var settingsCancellables = Set<AnyCancellable>()
    
    // Safety thresholds parameters
    private var lastPlayTime: Date = Date()
    private var consecutiveFailureCount = 0
    private let maxAllowedFailures = 3
    
    private var cachedPlaybackRate: Float = 1.0
    private var cachedPitchShift: Float = 0.0
    private var currentMicMonitorState: Bool? = nil
    
    private var isResettingEngine = false
    
    // CRITICAL HARDWARE FIREWALL TIMESTAMP FOR iOS INITIAL COLD-START INTERRUPTS
    private var lastSchedulingPassTimestamp: Date = Date.distantPast
    
    // Track which playback session is active – used to discard stale timer updates
    private var playSessionID: UUID?
    
    // PROGRESS SLIDER SYSTEM EXPOSURES
    @Published var currentProgressPosition: TimeInterval = 0.0
    @Published var activeTrackDuration: TimeInterval = 0.0
    private var audioSampleRate: Double = 44100.0
    private var audioTotalFrames: AVAudioFrameCount = 0
    
    // iOS Hardware Synchronization States
    private var systemStartSampleTime: AVAudioFramePosition = 0
    private var hasAssignedSampleAnchor: Bool = false
    
    // Increment tracker used to reset slider positions across track loops safely
    @Published var trackLoopCounter: Int = 0
    
    @Published var isSeekingTimeline = false
    private var seekSampleOffset: TimeInterval = 0.0
    
    @Published var isPlaying: Bool = false
    @Published var activeTrackTitle: String = ""
    
    @Published var masterVolume: Float = 1.0 {
        didSet {
            if useFallbackEngine {
                fallbackPlayerA?.volume = masterVolume
                fallbackPlayerB?.volume = masterVolume
            } else {
                mixerA.volume = masterVolume
            }
        }
    }
    
    private override init() {
        super.init()
        
        // 1. Audio session first (iOS)
        #if os(iOS)
        setupAudioSession()
        #endif
        
        // 2. Build the engine graph (do NOT start yet)
        setupAudioEngineGraph()
    }
    
    // Call this once from the splash screen to warm up the engine
    func prepareEngine() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        if !audioEngine.isRunning {
            do {
                try audioEngine.start()
                print("🔊 [AudioManager] Engine prepared and started successfully.")
            } catch {
                print("⚠️ [AudioManager] Engine start failed during preparation: \(error.localizedDescription)")
                useFallbackEngine = true
            }
        }
    }
    
    private func ensureEngineRunning() -> Bool {
        guard !useFallbackEngine else { return false }
        if audioEngine.isRunning { return true }
        
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        
        do {
            audioEngine.prepare()
            try audioEngine.start()
            // Give the system a fraction of a second to stabilise the route
            Thread.sleep(forTimeInterval: 0.05)
            return audioEngine.isRunning
        } catch {
            print("⚠️ [AudioManager] Engine restart failed: \(error.localizedDescription)")
            useFallbackEngine = true
            return false
        }
    }
    
    private func setupAudioEngineGraph() {
        audioEngine.attach(playerNodeA)
        audioEngine.attach(timePitchNodeA)
        audioEngine.attach(mixerA)
        audioEngine.attach(micMonitorMixer)
        
        let mainMixer = audioEngine.mainMixerNode
        let standardFormat = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2)
            ?? AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100.0, channels: 2, interleaved: false)!
        
        audioEngine.connect(playerNodeA, to: timePitchNodeA, format: standardFormat)
        audioEngine.connect(timePitchNodeA, to: mixerA, format: standardFormat)
        audioEngine.connect(mixerA, to: mainMixer, format: standardFormat)
        audioEngine.connect(micMonitorMixer, to: mainMixer, format: standardFormat)
        
        mixerA.volume = masterVolume
        micMonitorMixer.volume = 0.0
        
        audioEngine.prepare()
    }
    
    #if os(iOS)
    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetoothHFP, .mixWithOthers]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ [AudioManager] iOS Audio Session setup failed: \(error.localizedDescription)")
        }
    }
    #endif
    
    func observeEngineSettings(using settings: FlowSettings) {
        self.settingsReference = settings
        settingsCancellables.removeAll()
        
        settings.$playbackSpeed
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] targetSpeed in
                guard let self = self else { return }
                let rateValue = Float(targetSpeed)
                if self.useFallbackEngine {
                    if self.fallbackPlayerA?.rate != rateValue {
                        self.fallbackPlayerA?.rate = rateValue
                    }
                } else {
                    if self.cachedPlaybackRate != rateValue {
                        self.cachedPlaybackRate = rateValue
                        self.timePitchNodeA.rate = rateValue
                    }
                }
            }
            .store(in: &settingsCancellables)
            
        settings.$pitchShiftSemitones
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] semitones in
                guard let self = self, !self.useFallbackEngine else { return }
                let pitchValue = Float(semitones * 100)
                if self.cachedPitchShift != pitchValue {
                    self.cachedPitchShift = pitchValue
                    self.timePitchNodeA.pitch = pitchValue
                }
            }
            .store(in: &settingsCancellables)
            
        settings.$enableMicMonitor
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                guard let self = self, !self.useFallbackEngine else { return }
                self.toggleHardwareMicMonitor(enabled: enabled)
            }
            .store(in: &settingsCancellables)
    }
    
    private func toggleHardwareMicMonitor(enabled: Bool) {
        if currentMicMonitorState == enabled { return }
        
        // Track if this is the very first time this function is firing (cold start)
        let isInitialSetup = (currentMicMonitorState == nil)
        currentMicMonitorState = enabled
        
        #if os(macOS)
        micMonitorMixer.volume = 0.0
        return
        #else
        
        // 🚀 FIX: If this is the cold-start pass and monitoring is disabled,
        // exit immediately WITHOUT accessing audioEngine.inputNode.
        // This protects the audio graph from breaking right before playback.
        guard !isInitialSetup || enabled else {
            micMonitorMixer.volume = 0.0
            return
        }
        
        let inputNode = audioEngine.inputNode
        audioEngine.disconnectNodeOutput(inputNode)
        
        guard enabled else {
            micMonitorMixer.volume = 0.0
            return
        }
        
        let hardwareInputFormat = inputNode.inputFormat(forBus: 0)
        if hardwareInputFormat.sampleRate > 8000 && hardwareInputFormat.channelCount > 0 {
            audioEngine.connect(inputNode, to: micMonitorMixer, fromBus: 0, toBus: 0, format: hardwareInputFormat)
            micMonitorMixer.volume = 1.0
        } else {
            micMonitorMixer.volume = 0.0
        }
        #endif
    }
    
    func play(trackName: String, using settings: FlowSettings) {
        let formattedTrackName = (trackName.hasSuffix(".mp3") || trackName.hasSuffix(".m4a")) ? trackName : "\(trackName).mp3"
        let now = Date()
        
        // HARDWARE RE-ENTRANCY FIREWALL LOCK
        if now.timeIntervalSince(lastSchedulingPassTimestamp) < 0.40 {
            print("📝 [Hardware Firewall] Duplicate play command rejected.")
            return
        }
        
        if isPlaying && activeTrackTitle == formattedTrackName {
            return
        }
        
        lastSchedulingPassTimestamp = now
        lastPlayTime = now
        
        if isPlaying { stop() }
        
        observeEngineSettings(using: settings)
        
        let cleanInputName = trackName.replacingOccurrences(of: ".mp3", with: "").replacingOccurrences(of: ".m4a", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        let factoryNames = ["Chrome_On_The_Curb", "JazzyFlow", "JazzyFlowDeep", "Late_August_Porch", "Low_Rider_Glide", "Morning_on_the_Deck", "Passing_Thru_Willow_Street", "Under_The_Surface"]
        let isStrictFactoryAsset = factoryNames.contains { $0.lowercased() == cleanInputName.lowercased() }
        
        var targetURL: URL? = nil
        if isStrictFactoryAsset {
            targetURL = Bundle.main.url(forResource: cleanInputName, withExtension: "mp3")
        }
        if targetURL == nil {
            targetURL = LocalStorageManager.shared.resolveAudioURL(for: formattedTrackName)
        }
        
        guard let url = targetURL else {
            self.handleTrackPlaybackFailure()
            return
        }
        
        self.isSeekingTimeline = false
        self.seekSampleOffset = 0.0
        
        if !useFallbackEngine {
            if !ensureEngineRunning() {
                useFallbackEngine = true
                playFallback(url: url, trackName: formattedTrackName, settings: settings)
                return
            }
            playAdvanced(url: url, trackName: formattedTrackName, settings: settings)
        } else {
            playFallback(url: url, trackName: formattedTrackName, settings: settings)
        }
    }
    
    private func playAdvanced(url: URL, trackName: String, settings: FlowSettings) {
        do {
            isResettingEngine = true
            playerNodeA.stop()
            playerNodeA.reset()
            
            self.seekSampleOffset = 0.0
            self.currentProgressPosition = 0.0
            self.hasAssignedSampleAnchor = false
            self.systemStartSampleTime = 0
            self.trackLoopCounter += 1
            
            let audioFile = try AVAudioFile(forReading: url)
            guard audioFile.length > 1000 else {
                throw NSError(domain: "com.freeflow.audio", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid file bounds"])
            }
            
            self.audioSampleRate = audioFile.processingFormat.sampleRate
            self.audioTotalFrames = AVAudioFrameCount(audioFile.length)
            self.activeTrackDuration = Double(audioFile.length) / audioSampleRate
            
            cachedPlaybackRate = Float(settings.playbackSpeed)
            cachedPitchShift = Float(settings.pitchShiftSemitones * 100)
            
            timePitchNodeA.rate = 1.0
            timePitchNodeA.pitch = 0.0
            mixerA.volume = masterVolume
            
            playerNodeA.prepare(withFrameCount: audioTotalFrames)
            scheduleStandardFilePlayback(audioFile, settings: settings)
            
            // INSULATE AUDIO LAYER BY PRE-STARTING GRAPH MANUALLY ON COLD INITIALIZATION PASS
            var engineHadToStart = false
            if !audioEngine.isRunning {
                audioEngine.prepare()
                try audioEngine.start()
                engineHadToStart = true
            }
            
            isResettingEngine = false
            self.isPlaying = true
            self.activeTrackTitle = trackName
            
            let sessionID = UUID()
            self.playSessionID = sessionID
            
            // CRITICAL iOS HARDWARE COLD BOOT SYNCHRONIZATION OVERRIDE FENCE
            // Introduces a tiny 20ms execution buffer *only* if the engine had to wake up from an idle state.
            // This guarantees the hardware output channels are active before writing data frames.
            if engineHadToStart {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
                    guard let self = self, self.isPlaying, self.playSessionID == sessionID else { return }
                    self.playerNodeA.play(at: nil)
                    self.consecutiveFailureCount = 0
                    
                    self.timePitchNodeA.rate = self.cachedPlaybackRate
                    self.timePitchNodeA.pitch = self.cachedPitchShift
                }
            } else {
                self.playerNodeA.play(at: nil)
                self.consecutiveFailureCount = 0
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    guard let self = self, self.isPlaying, !self.isResettingEngine else { return }
                    self.timePitchNodeA.rate = self.cachedPlaybackRate
                    self.timePitchNodeA.pitch = self.cachedPitchShift
                }
            }
            
            print("🔊 [AudioManager] Pro Audio Engine streaming locked & active: \(trackName)")
        } catch {
            isResettingEngine = false
            useFallbackEngine = true
            playFallback(url: url, trackName: trackName, settings: settings)
        }
    }
    
    private func playFallback(url: URL, trackName: String, settings: FlowSettings) {
        do {
            fallbackPlayerA = try AVAudioPlayer(contentsOf: url)
            fallbackPlayerA?.delegate = self
            fallbackPlayerA?.volume = masterVolume
            fallbackPlayerA?.numberOfLoops = (settings.endBehavior == .loopTrack) ? -1 : 0
            fallbackPlayerA?.enableRate = true
            fallbackPlayerA?.rate = Float(settings.playbackSpeed)
            
            self.currentProgressPosition = 0.0
            fallbackPlayerA?.currentTime = 0.0
            fallbackPlayerA?.prepareToPlay()
            
            self.activeTrackDuration = fallbackPlayerA?.duration ?? 0.0
            self.trackLoopCounter += 1
            
            let success = fallbackPlayerA?.play() ?? false
            if success {
                isPlaying = true
                activeTrackTitle = trackName
                consecutiveFailureCount = 0
                
                let sessionID = UUID()
                self.playSessionID = sessionID
                print("🔊 [AudioManager] Fallback Audio Engine locked & active: \(trackName)")
            } else {
                handleTrackPlaybackFailure()
            }
        } catch {
            handleTrackPlaybackFailure()
        }
    }
    
    private func scheduleStandardFilePlayback(_ audioFile: AVAudioFile, settings: FlowSettings) {
        playerNodeA.scheduleFile(audioFile, at: nil, completionCallbackType: .dataRendered) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                guard !self.isSeekingTimeline && !self.isResettingEngine && self.isPlaying else { return }
                
                if settings.endBehavior == .loopTrack {
                    self.triggerLoopCyclePass(audioFile, settings: settings)
                } else {
                    self.handleTrackPlaybackCompletion()
                }
            }
        }
    }
    
    private func triggerLoopCyclePass(_ file: AVAudioFile, settings: FlowSettings) {
        guard isPlaying && !isResettingEngine && !isSeekingTimeline else { return }
        
        self.seekSampleOffset = 0.0
        self.hasAssignedSampleAnchor = false
        self.systemStartSampleTime = 0
        self.trackLoopCounter += 1
        
        playerNodeA.prepare(withFrameCount: AVAudioFrameCount(file.length))
        
        playerNodeA.scheduleFile(file, at: nil, completionCallbackType: .dataRendered) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                guard !self.isSeekingTimeline && !self.isResettingEngine && self.isPlaying else { return }
                
                if settings.endBehavior == .loopTrack {
                    self.triggerLoopCyclePass(file, settings: settings)
                } else {
                    self.handleTrackPlaybackCompletion()
                }
            }
        }
    }
    
    func seekToProgressPercentage(_ percentage: Double) {
        guard !activeTrackTitle.isEmpty, activeTrackDuration > 0 else { return }
        let targetTime = percentage * activeTrackDuration
        
        self.isSeekingTimeline = true
        self.currentProgressPosition = targetTime
        
        if useFallbackEngine {
            fallbackPlayerA?.currentTime = targetTime
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.isSeekingTimeline = false
            }
        } else {
            guard let settings = settingsReference else {
                self.isSeekingTimeline = false
                return
            }
            let playingStateBuffer = isPlaying
            playerNodeA.stop()
            playerNodeA.reset()
            
            self.hasAssignedSampleAnchor = false
            self.systemStartSampleTime = 0
            
            if !audioEngine.isRunning { try? audioEngine.start() }
            
            let cleanInputName = activeTrackTitle.replacingOccurrences(of: ".mp3", with: "").replacingOccurrences(of: ".m4a", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            let factoryNames = ["Chrome_On_The_Curb", "JazzyFlow", "JazzyFlowDeep", "Late_August_Porch", "Low_Rider_Glide", "Morning_on_the_Deck", "Passing_Thru_Willow_Street", "Under_The_Surface"]
            let isStrictFactoryAsset = factoryNames.contains { $0.lowercased() == cleanInputName.lowercased() }
            
            var targetURL: URL? = nil
            if isStrictFactoryAsset {
                targetURL = Bundle.main.url(forResource: cleanInputName, withExtension: "mp3")
            } else {
                targetURL = LocalStorageManager.shared.resolveAudioURL(for: activeTrackTitle)
            }
            
            guard let url = targetURL, let audioFile = try? AVAudioFile(forReading: url) else {
                self.isSeekingTimeline = false
                return
            }
            
            let targetFrame = Int64(percentage * Double(audioFile.length))
            let framesToPlay = AVAudioFrameCount(Int64(audioFile.length) - targetFrame)
            
            if framesToPlay > 100 {
                self.seekSampleOffset = targetTime
                
                playerNodeA.prepare(withFrameCount: framesToPlay)
                
                playerNodeA.scheduleSegment(audioFile, startingFrame: targetFrame, frameCount: framesToPlay, at: nil) { [weak self] in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        guard !self.isSeekingTimeline && !self.isResettingEngine && self.isPlaying else { return }
                        
                        if settings.endBehavior == .loopTrack {
                            self.triggerLoopCyclePass(audioFile, settings: settings)
                        } else {
                            self.handleTrackPlaybackCompletion()
                        }
                    }
                }
                
                if playingStateBuffer {
                    if !audioEngine.isRunning { try? audioEngine.start() }
                    playerNodeA.play(at: nil)
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    guard let self = self else { return }
                    self.isSeekingTimeline = false
                }
            } else {
                self.isSeekingTimeline = false
                handleTrackPlaybackCompletion()
            }
        }
    }
    
    func queryCalculatedTimelineProgressPosition() -> TimeInterval {
        if !isPlaying { return 0.0 }
        if isSeekingTimeline { return currentProgressPosition }
        
        if useFallbackEngine {
            return fallbackPlayerA?.currentTime ?? 0.0
        }
        
        guard let nodeTime = playerNodeA.lastRenderTime,
              nodeTime.isSampleTimeValid,
              let playerTime = playerNodeA.playerTime(forNodeTime: nodeTime) else {
            return currentProgressPosition
        }
        
        let sampleTime = playerTime.sampleTime
        if !hasAssignedSampleAnchor {
            systemStartSampleTime = sampleTime
            hasAssignedSampleAnchor = true
        }
        
        let sessionDeltaFrames = sampleTime - systemStartSampleTime
        guard sessionDeltaFrames >= 0 else { return currentProgressPosition }
        
        let currentSamplePosition = (Double(sessionDeltaFrames) / playerTime.sampleRate) + seekSampleOffset
        if activeTrackDuration > 0 {
            return currentSamplePosition.truncatingRemainder(dividingBy: activeTrackDuration)
        }
        return currentProgressPosition
    }
    
    func deleteCustomTrackStateCleanup(fileName: String) {
        if activeTrackTitle == fileName {
            self.stop()
        }
    }
    
    func stop() {
        isResettingEngine = true
        isPlaying = false
        isSeekingTimeline = false
        seekSampleOffset = 0.0
        hasAssignedSampleAnchor = false
        systemStartSampleTime = 0
        if useFallbackEngine {
            fallbackPlayerA?.stop()
            fallbackPlayerB?.stop()
            fallbackPlayerA = nil
            fallbackPlayerB = nil
        } else {
            playerNodeA.stop()
            playerNodeA.reset()
        }
        activeTrackTitle = ""
        currentProgressPosition = 0.0
        activeTrackDuration = 0.0
        isResettingEngine = false
        playSessionID = nil
        trackLoopCounter += 1
    }
    
    private func handleTrackPlaybackCompletion() {
        guard let settings = settingsReference, isPlaying, !isResettingEngine, !isSeekingTimeline else { return }
        
        switch settings.endBehavior {
        case .loopTrack:
            self.play(trackName: activeTrackTitle, using: settings)
        case .nextTrack:
            advanceToNextTrack()
        }
    }
    
    private func handleTrackPlaybackFailure() {
        self.stop()
        consecutiveFailureCount += 1
        
        guard let settings = settingsReference else { return }
        if consecutiveFailureCount >= maxAllowedFailures {
            consecutiveFailureCount = 0
            return
        }
        
        if settings.endBehavior == .nextTrack {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.advanceToNextTrack()
            }
        }
    }
    
    private func advanceToNextTrack() {
        guard let settings = settingsReference, !isResettingEngine, !isSeekingTimeline else { return }
        
        self.seekSampleOffset = 0.0
        self.currentProgressPosition = 0.0
        self.hasAssignedSampleAnchor = false
        self.systemStartSampleTime = 0
        self.trackLoopCounter += 1
        
        if !useFallbackEngine {
            playerNodeA.stop()
            playerNodeA.reset()
        }
        
        let currentSearchName = activeTrackTitle.isEmpty ? settings.selectedTrack : activeTrackTitle
        let cleanSearchName = currentSearchName.replacingOccurrences(of: ".mp3", with: "")
                                                .replacingOccurrences(of: ".m4a", with: "")
                                                .lowercased()
        
        if let currentIndex = settings.instrumentalBackingTracks.firstIndex(where: { track in
            let cleanTrackName = track.replacingOccurrences(of: ".mp3", with: "")
                                      .replacingOccurrences(of: ".m4a", with: "")
                                      .lowercased()
            return cleanTrackName == cleanSearchName
        }) {
            let nextIndex = (currentIndex + 1) % settings.instrumentalBackingTracks.count
            let nextTrackName = settings.instrumentalBackingTracks[nextIndex]
            
            DispatchQueue.main.async {
                settings.selectedTrack = nextTrackName
                self.play(trackName: nextTrackName, using: settings)
            }
        } else {
            if !settings.instrumentalBackingTracks.isEmpty {
                let fallbackTrack = settings.instrumentalBackingTracks[0]
                DispatchQueue.main.async {
                    settings.selectedTrack = fallbackTrack
                    self.play(trackName: fallbackTrack, using: settings)
                }
            }
        }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard !isSeekingTimeline else { return }
        
        if flag {
            consecutiveFailureCount = 0
            handleTrackPlaybackCompletion()
        } else {
            handleTrackPlaybackFailure()
        }
    }
}
