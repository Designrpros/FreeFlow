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
        
        #if os(macOS)
        self.useFallbackEngine = true
        print("🔊 [AudioManager] macOS Sandbox environment detected. Primed fallback engine.")
        #else
        setupAudioEngineGraph()
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
            print("⚠️ [AudioManager] Node-graph initialization failed.")
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
        
        guard !useFallbackEngine else { return }
        
        settings.$playbackSpeed
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] targetSpeed in
                guard let self = self, !self.useFallbackEngine else { return }
                let rateValue = Float(targetSpeed)
                if self.cachedPlaybackRate != rateValue {
                    self.cachedPlaybackRate = rateValue
                    self.timePitchNodeA.rate = rateValue
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
        currentMicMonitorState = enabled
        
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
        
        guard LocalStorageManager.shared.isLocalFileReady(fileName: formattedTrackName) else {
            _ = LocalStorageManager.shared.resolveAudioURL(for: formattedTrackName)
            self.handleTrackPlaybackFailure()
            return
        }
        
        guard let url = LocalStorageManager.shared.resolveAudioURL(for: formattedTrackName) else {
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
                let pcmProcessingFormat = audioFile.processingFormat
                
                self.audioSampleRate = pcmProcessingFormat.sampleRate
                self.audioTotalFrames = AVAudioFrameCount(audioFile.length)
                self.activeTrackDuration = Double(audioFile.length) / audioSampleRate
                self.currentProgressPosition = 0.0
                
                audioEngine.stop()
                audioEngine.disconnectNodeOutput(playerNodeA)
                audioEngine.disconnectNodeOutput(timePitchNodeA)
                audioEngine.disconnectNodeOutput(mixerA)
                
                let mainMixer = audioEngine.mainMixerNode
                audioEngine.connect(playerNodeA, to: timePitchNodeA, format: pcmProcessingFormat)
                audioEngine.connect(timePitchNodeA, to: mixerA, format: pcmProcessingFormat)
                audioEngine.connect(mixerA, to: mainMixer, format: pcmProcessingFormat)
                
                cachedPlaybackRate = Float(settings.playbackSpeed)
                cachedPitchShift = Float(settings.pitchShiftSemitones * 100)
                
                timePitchNodeA.rate = cachedPlaybackRate
                timePitchNodeA.pitch = cachedPitchShift
                
                mixerA.volume = masterVolume
                mainMixer.volume = 1.0
                
                audioEngine.prepare()
                if !audioEngine.isRunning {
                    try audioEngine.start()
                }
                
                playerNodeA.reset()
                isResettingEngine = false
                
                playerNodeA.prepare(withFrameCount: audioTotalFrames)
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
                
                if !audioEngine.isRunning {
                    try audioEngine.start()
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
                    guard let self = self else { return }
                    if !self.isResettingEngine {
                        if !self.audioEngine.isRunning {
                            try? self.audioEngine.start()
                        }
                        
                        self.playerNodeA.play()
                        self.isPlaying = true
                        self.activeTrackTitle = formattedTrackName
                        self.consecutiveFailureCount = 0
                        self.startProgressTrackingTimer()
                        print("🔊 [AudioManager] Pro Audio Engine streaming locked & active: \(formattedTrackName)")
                    }
                }
                return
            } catch {
                isResettingEngine = false
                useFallbackEngine = true
            }
        }
        
        // FALLBACK STREAM SYSTEM
        do {
            fallbackPlayerA = try AVAudioPlayer(contentsOf: url)
            fallbackPlayerA?.delegate = self
            fallbackPlayerA?.volume = masterVolume
            fallbackPlayerA?.numberOfLoops = settings.loopWithCrossfade ? -1 : ((settings.endBehavior == .loopTrack) ? -1 : 0)
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
        
        // Lock mutex block securely across both engine frameworks immediately
        self.isSeekingTimeline = true
        stopTrackingTimer()
        
        // Force state updates to prevent immediate regression/snapping resets
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
            
            guard let url = LocalStorageManager.shared.resolveAudioURL(for: activeTrackTitle),
                  let audioFile = try? AVAudioFile(forReading: url) else {
                self.isSeekingTimeline = false
                return
            }
            
            let targetFrame = Int64(percentage * Double(audioFile.length))
            let framesToPlay = AVAudioFrameCount(Int64(audioFile.length) - targetFrame)
            
            if framesToPlay > 100 {
                // Set sample offset so timer handles mathematical updates seamlessly
                self.seekSampleOffset = targetTime
                
                playerNodeA.prepare(withFrameCount: framesToPlay)
                playerNodeA.scheduleSegment(audioFile, startingFrame: targetFrame, frameCount: framesToPlay, at: nil, completionCallbackType: .dataRendered) { [weak self] _ in
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
                    playerNodeA.play()
                }
                
                // Let legacy interrupt callbacks settle down entirely before unlocking the timer
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
                // Skip UI updating loops entirely while scrubbing is active
                guard self.isPlaying && !self.isSeekingTimeline else { return }
                
                if self.useFallbackEngine {
                    self.currentProgressPosition = self.fallbackPlayerA?.currentTime ?? 0.0
                } else {
                    if let nodeTime = self.playerNodeA.lastRenderTime,
                       let playerTime = self.playerNodeA.playerTime(forNodeTime: nodeTime) {
                        
                        let currentSamplePosition = (Double(playerTime.sampleTime) / playerTime.sampleRate) + self.seekSampleOffset
                        
                        if self.activeTrackDuration > 0 {
                            self.currentProgressPosition = currentSamplePosition.truncatingRemainder(dividingBy: self.activeTrackDuration)
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
            playerNodeA.stop()
            playerNodeA.reset()
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
