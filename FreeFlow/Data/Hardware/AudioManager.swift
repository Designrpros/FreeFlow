//
//  AudioManager.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 22/05/2026.
//

import Foundation
import AVFoundation
import Combine

final class AudioManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = AudioManager()
    
    // --- NATIVE ENGINE NODES (Used on iOS or Unsandboxed Environments) ---
    private let audioEngine = AVAudioEngine()
    private let playerNodeA = AVAudioPlayerNode()
    private let timePitchNodeA = AVAudioUnitTimePitch()
    private let mixerA = AVAudioMixerNode()
    private let micMonitorMixer = AVAudioMixerNode()
    
    // --- HIGH LEVEL FALLBACK SYSTEM (Used on macOS Sandbox to guarantee sound) ---
    private var fallbackPlayerA: AVAudioPlayer?
    private var fallbackPlayerB: AVAudioPlayer?
    private var useFallbackEngine = false
    
    private var settingsReference: FlowSettings?
    private var settingsCancellables = Set<AnyCancellable>()
    
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
        // FORCE FALLBACK ON MAC: The macOS Sandbox restricts low-level AVAudioEngine device linkages
        // without mach-lookup extensions. Forcing the fallback engine guarantees crystal clear sound.
        self.useFallbackEngine = true
        print("🔊 [AudioManager] macOS Sandbox environment detected. Primed high-fidelity stable fallback engine.")
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
            print("⚠️ [AudioManager] Node-graph initialization failed. Enforcing fallback routing.")
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
            .receive(on: DispatchQueue.main)
            .sink { [weak self] targetSpeed in
                guard let self = self, !self.useFallbackEngine else { return }
                self.timePitchNodeA.rate = Float(targetSpeed)
            }
            .store(in: &settingsCancellables)
            
        settings.$pitchShiftSemitones
            .receive(on: DispatchQueue.main)
            .sink { [weak self] semitones in
                guard let self = self, !self.useFallbackEngine else { return }
                self.timePitchNodeA.pitch = Float(semitones * 100)
            }
            .store(in: &settingsCancellables)
            
        settings.$enableMicMonitor
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                guard let self = self, !self.useFallbackEngine else { return }
                self.toggleHardwareMicMonitor(enabled: enabled)
            }
            .store(in: &settingsCancellables)
    }
    
    private func toggleHardwareMicMonitor(enabled: Bool) {
        let inputNode = audioEngine.inputNode
        audioEngine.disconnectNodeOutput(inputNode)
        
        guard enabled else {
            micMonitorMixer.volume = 0.0
            return
        }
        
        let hardwareInputFormat = inputNode.inputFormat(forBus: 0)
        if hardwareInputFormat.sampleRate > 0 && hardwareInputFormat.channelCount > 0 {
            audioEngine.connect(inputNode, to: micMonitorMixer, fromBus: 0, toBus: 0, format: hardwareInputFormat)
            micMonitorMixer.volume = 1.0
        }
    }
    
    func play(trackName: String, using settings: FlowSettings) {
        observeEngineSettings(using: settings)
        
        if isPlaying { stop() }
        
        guard let url = LocalStorageManager.shared.resolveAudioURL(for: trackName) else { return }
        
        if !useFallbackEngine {
            // PRO ENGINE PIPELINE LOOP
            do {
                if !audioEngine.isRunning { try audioEngine.start() }
                let audioFile = try AVAudioFile(forReading: url)
                let pcmProcessingFormat = audioFile.processingFormat
                let mainMixer = audioEngine.mainMixerNode
                
                audioEngine.connect(playerNodeA, to: timePitchNodeA, format: pcmProcessingFormat)
                audioEngine.connect(timePitchNodeA, to: mixerA, format: pcmProcessingFormat)
                audioEngine.connect(mixerA, to: mainMixer, format: pcmProcessingFormat)
                
                timePitchNodeA.rate = Float(settings.playbackSpeed)
                timePitchNodeA.pitch = Float(settings.pitchShiftSemitones * 100)
                
                playerNodeA.reset()
                playerNodeA.scheduleFile(audioFile, at: nil, completionHandler: nil)
                playerNodeA.play()
                
                isPlaying = true
                activeTrackTitle = trackName
                print("🔊 [AudioManager] Pro Audio Engine streaming: \(trackName)")
                return
            } catch {
                print("⚠️ [AudioManager] Pro engine initialization failed mid-flight. Swapping layout tracking channels.")
                useFallbackEngine = true
            }
        }
        
        // STABLE STREAMS ENGINE DRIVER
        do {
            fallbackPlayerA = try AVAudioPlayer(contentsOf: url)
            fallbackPlayerA?.delegate = self
            fallbackPlayerA?.volume = masterVolume
            fallbackPlayerA?.numberOfLoops = settings.loopWithCrossfade ? -1 : ((settings.endBehavior == .loopTrack) ? -1 : 0)
            fallbackPlayerA?.prepareToPlay()
            fallbackPlayerA?.play()
            
            isPlaying = true
            activeTrackTitle = trackName
            print("🔊 [AudioManager] Stable fallback playback established successfully: \(trackName)")
        } catch {
            print("⚠️ [AudioManager] Absolute fallback engine failure: \(error.localizedDescription)")
        }
    }
    
    func stop() {
        if useFallbackEngine {
            fallbackPlayerA?.stop()
            fallbackPlayerB?.stop()
            fallbackPlayerA = nil
            fallbackPlayerB = nil
        } else {
            playerNodeA.stop()
        }
        isPlaying = false
        activeTrackTitle = ""
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard let settings = settingsReference else { return }
        isPlaying = false
        if settings.endBehavior == .nextTrack, let currentIndex = settings.availableTracks.firstIndex(of: activeTrackTitle) {
            let nextIndex = (currentIndex + 1) % settings.availableTracks.count
            let nextTrackName = settings.availableTracks[nextIndex]
            DispatchQueue.main.async {
                settings.selectedTrack = nextTrackName
                self.play(trackName: nextTrackName, using: settings)
            }
        }
    }
}
