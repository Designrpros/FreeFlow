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
    
    // PROGRESS SLIDER SYSTEM EXPOSURES
    @Published var currentProgressPosition: TimeInterval = 0.0
    @Published var activeTrackDuration: TimeInterval = 0.0
    private var trackingTimer: Timer?
    private var audioSampleRate: Double = 44100.0
    private var audioTotalFrames: AVAudioFrameCount = 0
    
    // 🚀 CRITICAL RESILIENT MUTEX PROTECTION FLAG (Exposed to UI):
    // Prevents BOTH AVAudioPlayer and AVAudioPlayerNode manual interruptions from triggering track forwarding
    @Published var isSeekingTimeline = false
    
    // Tracks the sample offset when starting a segment seek so the timer calculation stays linear
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
        
        // 🚀 PRO AUDIO ENGINE ENABLED GLOBALLY:
        // We initialize the advanced node-graph graph across all platforms so pitch and warp function everywhere.
        setupAudioEngineGraph()
        #if os(iOS)
        setupAudioSession()
        #endif
    }
    
    private func setupAudioEngineGraph() {
        audioEngine.attach(playerNodeA)
        audioEngine.attach(timePitchNodeA)
        audioEngine.attach(mixerA)
        audioEngine.attach(micMonitorMixer)
        
        let mainMixer = audioEngine.mainMixerNode
        let standardFormat = AVAudioFormat(standardFormatWithSampleRate: 44100.0, channels: 2) ?? AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100.0, channels: 2, interleaved: false)!
        
        audioEngine.connect(playerNodeA, to: timePitchNodeA, format: standardFormat)
        audioEngine.connect(timePitchNodeA, to: mixerA, format: standardFormat)
        audioEngine.connect(mixerA, to: mainMixer, format: standardFormat)
        audioEngine.connect(micMonitorMixer, to: mainMixer, format: standardFormat)
        
        mixerA.volume = masterVolume
        micMonitorMixer.volume = 0.0
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
            useFallbackEngine = false
            print("🔊 [AudioManager] Pro node-graph initialized successfully.")
        } catch {
            print("⚠️ [AudioManager] Node-graph initialization failed. Reverting to fallback system layers.")
            useFallbackEngine = true
        }
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
            try session.setActive(true)
        } catch {
            print("⚠️ [AudioManager] iOS Audio Session routing failed: \(error.localizedDescription)")
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
                
                // 🚀 PITCH UNIT CORRECTION: AVAudioUnitTimePitch handles transformations measured in cents.
                // 1 Semitone is equivalent to 100 cents.
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
        currentMicMonitorState = enabled
        
        // 🚀 SANDBOX DEFENSE GATING: Avoid making requests to an unentitled inputNode on a sandboxed Mac environment
        #if os(macOS)
        micMonitorMixer.volume = 0.0
        return
        #else
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
        observeEngineSettings(using: settings)
        
        let formattedTrackName = (trackName.hasSuffix(".mp3") || trackName.hasSuffix(".m4a")) ? trackName : "\(trackName).mp3"
        
        if isPlaying && activeTrackTitle == formattedTrackName {
            return
        }
        
        let now = Date()
        if now.timeIntervalSince(lastPlayTime) < 0.2 {
            return
        }
        lastPlayTime = now
        
        if isPlaying { stop() }
        
        // Dynamic path checking rules map safely to locate internal bundles or local document containers
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
            do {
                isResettingEngine = true
                playerNodeA.stop()
                
                let audioFile = try AVAudioFile(forReading: url)
                
                guard audioFile.length > 1000 else {
                    throw NSError(domain: "com.freeflow.audio", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid file bounds"])
                }
                
                self.audioSampleRate = audioFile.processingFormat.sampleRate
                self.audioTotalFrames = AVAudioFrameCount(audioFile.length)
                self.activeTrackDuration = Double(audioFile.length) / audioSampleRate
                self.currentProgressPosition = 0.0
                
                // 🚀 STABLE CONNECTIVITY PIPELINE FLOW:
                // We keep the static node structures continuously running, which clears layout faults.
                if !audioEngine.isRunning {
                    audioEngine.prepare()
                    try audioEngine.start()
                }
                
                cachedPlaybackRate = Float(settings.playbackSpeed)
                cachedPitchShift = Float(settings.pitchShiftSemitones * 100)
                
                timePitchNodeA.rate = 1.0
                timePitchNodeA.pitch = 0.0
                mixerA.volume = masterVolume
                
                playerNodeA.prepare(withFrameCount: audioTotalFrames)
                scheduleStandardFilePlayback(audioFile, settings: settings)
                
                isResettingEngine = false
                self.isPlaying = true
                self.activeTrackTitle = formattedTrackName
                
                // Explicit nil frame declaration sets the hardware device time baseline up correctly
                self.playerNodeA.play(at: nil)
                self.consecutiveFailureCount = 0
                self.startProgressTrackingTimer()
                
                // Apply the scale configurations asynchronously after the timeline opens up smoothly
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    guard let self = self, self.isPlaying, !self.isResettingEngine else { return }
                    self.timePitchNodeA.rate = self.cachedPlaybackRate
                    self.timePitchNodeA.pitch = self.cachedPitchShift
                }
                
                print("🔊 [AudioManager] Pro Audio Engine streaming locked & active: \(formattedTrackName)")
                return
            } catch {
                isResettingEngine = false
            }
        }
        
        // FALLBACK STREAM SYSTEM
        do {
            self.useFallbackEngine = true
            fallbackPlayerA = try AVAudioPlayer(contentsOf: url)
            fallbackPlayerA?.delegate = self
            fallbackPlayerA?.volume = masterVolume
            fallbackPlayerA?.numberOfLoops = (settings.endBehavior == .loopTrack) ? -1 : 0
            
            fallbackPlayerA?.enableRate = true
            fallbackPlayerA?.rate = Float(settings.playbackSpeed)
            
            fallbackPlayerA?.prepareToPlay()
            
            self.activeTrackDuration = fallbackPlayerA?.duration ?? 0.0
            self.currentProgressPosition = 0.0
            
            let success = fallbackPlayerA?.play() ?? false
            if success {
                isPlaying = true
                activeTrackTitle = formattedTrackName
                consecutiveFailureCount = 0
                self.startProgressTrackingTimer()
                print("🔊 [AudioManager] Fallback Audio Engine locked & active: \(formattedTrackName)")
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
        stopTrackingTimer()
        
        self.currentProgressPosition = targetTime
        
        if useFallbackEngine {
            fallbackPlayerA?.currentTime = targetTime
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.isSeekingTimeline = false
                if self.isPlaying { self.startProgressTrackingTimer() }
            }
        } else {
            guard let settings = settingsReference else {
                self.isSeekingTimeline = false
                return
            }
            let playingStateBuffer = isPlaying
            playerNodeA.stop()
            
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
                    playerNodeA.play(at: nil)
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    guard let self = self else { return }
                    self.isSeekingTimeline = false
                    if playingStateBuffer {
                        self.startProgressTrackingTimer()
                    }
                }
            } else {
                self.isSeekingTimeline = false
                handleTrackPlaybackCompletion()
            }
        }
    }
    
    private func startProgressTrackingTimer() {
        stopTrackingTimer()
        trackingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                guard self.isPlaying && !self.isSeekingTimeline else { return }
                
                if self.useFallbackEngine {
                    self.currentProgressPosition = self.fallbackPlayerA?.currentTime ?? 0.0
                } else {
                    if let nodeTime = self.playerNodeA.lastRenderTime {
                        guard nodeTime.isSampleTimeValid || nodeTime.isHostTimeValid else { return }
                        
                        if let playerTime = self.playerNodeA.playerTime(forNodeTime: nodeTime) {
                            let currentSamplePosition = (Double(playerTime.sampleTime) / playerTime.sampleRate) + self.seekSampleOffset
                            
                            if self.activeTrackDuration > 0 {
                                self.currentProgressPosition = currentSamplePosition.truncatingRemainder(dividingBy: self.activeTrackDuration)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func stopTrackingTimer() {
        trackingTimer?.invalidate()
        trackingTimer = nil
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
        stopTrackingTimer()
        if useFallbackEngine {
            fallbackPlayerA?.stop()
            fallbackPlayerB?.stop()
            fallbackPlayerA = nil
            fallbackPlayerB = nil
        } else {
            // Removing node reset calls preserves configuration attributes across consecutive track transformations
            playerNodeA.stop()
        }
        activeTrackTitle = ""
        currentProgressPosition = 0.0
        activeTrackDuration = 0.0
        isResettingEngine = false
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
        
        if !useFallbackEngine {
            playerNodeA.stop()
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



