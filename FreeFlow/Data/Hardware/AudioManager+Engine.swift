//
//  AudioManager+Engine.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 26/05/2026.
//

import Foundation
import AudioKit
import AVFoundation

extension AudioManager {
    
    @MainActor
    func prepareEngine() {
        print("🏗️ [Telemetry-Engine] Pre-warming core framework initialization registers...")
        
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
            print("📱 [Telemetry-Engine] Application AVAudioSession launched under low-latency baseline parameters.")
        } catch {
            print("⚠️ [Telemetry-Engine] Failed pre-warming iOS global session handles: \(error.localizedDescription)")
        }
        #endif
        
        rebuildEngineGraph(includeInput: false)
    }
    
    @MainActor
    internal func rebuildEngineGraph(includeInput: Bool) {
        print("🏗️ [Telemetry-Engine] Regenerating processing matrix topology. Hardware Input Included: \(includeInput)")
        
        let wasPlaying = isPlaying
        let currentTrackName = activeTrackTitle
        let currentPlaybackPosition = player.currentTime
        
        player.stop()
        engine.stop()
        
        let newEngine = AudioEngine()
        let newPlayer = AudioPlayer()
        let newTimePitch = TimePitch(newPlayer)
        let newMixer = Mixer()
        
        self.engine = newEngine
        self.player = newPlayer
        self.timePitch = newTimePitch
        self.mixer = newMixer
        
        newMixer.addInput(newTimePitch)
        
        if includeInput {
            let newMicMixer = Mixer()
            self.micMonitorMixer = newMicMixer
            
            if let inputNode = newEngine.input {
                newMicMixer.addInput(inputNode)
                newMixer.addInput(newMicMixer)
                
                do {
                    self.recorder = try NodeRecorder(node: inputNode)
                    print("🎙️ [Telemetry-Engine] Low-latency NodeRecorder successfully attached directly into core driver hardware layer.")
                } catch {
                    print("⚠️ [Telemetry-Engine] Failed to bind recorder instance nodes: \(error.localizedDescription)")
                }
            }
            
            let monitorEnabled = settingsReference?.enableMicMonitor ?? false
            newMicMixer.volume = monitorEnabled ? 1.0 : 0.0
            self.isInputAttached = true
        } else {
            self.recorder = nil
            self.isInputAttached = false
            print("🔊 [Telemetry-Engine] Graph compiled under isolated playback layout constraints. Microphone fully released.")
        }
        
        newEngine.output = newMixer
        newMixer.volume = masterVolume
        
        try? newEngine.start()
        
        if !currentTrackName.isEmpty {
            let cleanInputName = currentTrackName.replacingOccurrences(of: ".mp3", with: "").replacingOccurrences(of: ".m4a", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            var targetURL: URL? = nil
            
            let factoryNames = ["Chrome_On_The_Curb", "JazzyFlow", "JazzyFlowDeep", "Late_August_Porch", "Low_Rider_Glide", "Morning_on_the_Deck", "Passing_Thru_Willow_Street", "Under_The_Surface"]
            if factoryNames.contains(where: { $0.lowercased() == cleanInputName.lowercased() }) {
                targetURL = Bundle.main.url(forResource: cleanInputName, withExtension: "mp3")
            } else {
                targetURL = LocalStorageManager.shared.resolveAudioURL(for: currentTrackName)
            }
            
            if let url = targetURL {
                do {
                    try newPlayer.load(url: url)
                    if let settings = settingsReference {
                        newTimePitch.rate = Float(settings.playbackSpeed)
                        newTimePitch.pitch = Float(settings.pitchShiftSemitones * 100)
                        
                        // ✅ FIX: Reapply behavior logic constraints inside hotswap operations
                        if settings.endBehavior == .loopTrack {
                            newPlayer.isLooping = true
                        } else {
                            newPlayer.isLooping = false
                            // Completion handler disabled – relying on timer-based monitor only
                            newPlayer.completionHandler = nil
                        }
                    }
                    if wasPlaying {
                        newPlayer.seek(time: currentPlaybackPosition)
                        newPlayer.play()
                    }
                } catch {
                    print("⚠️ [Telemetry-Engine] Failed mapping hot-swap asset restoration steps: \(error.localizedDescription)")
                }
            }
        }
        
        setupHardwareRouteObservers()
    }
    
    internal func setupAudioEngineGraph() {
        if !engine.avEngine.isRunning {
            print("🏗️ [Telemetry-Engine] Graph offline. Pushing structural start pass...")
            try? engine.start()
        }
    }
    
    internal func setupHardwareRouteObservers() {
        print("📡 [Telemetry-Engine] Registering Core Audio framework hardware alteration change listeners...")
        NotificationCenter.default.removeObserver(self, name: .AVAudioEngineConfigurationChange, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEngineConfigurationChange),
            name: .AVAudioEngineConfigurationChange,
            object: engine.avEngine
        )
    }
    
    @objc internal func handleEngineConfigurationChange(_ notification: Notification) {
        print("🔄 [Telemetry-Engine] HARDWARE NOTIFICATION INTERCEPTED: .AVAudioEngineConfigurationChange broadcasted.")
        
        if !engine.avEngine.isRunning && isPlaying {
            print("🔄 [Telemetry-Engine] Graph disrupted mid-performance stream. Attempting seamless background recovery boot...")
            try? engine.start()
            player.play()
        }
    }
    
    @MainActor
    internal func toggleHardwareMicMonitor(enabled: Bool) {
        print("🎙️ [Telemetry-Engine] Request to alter local microphone hardware live monitoring track lane: \(enabled)")
        
        let needsInputAccess = enabled || (settingsReference?.isRecordingSession ?? false)
        
        if needsInputAccess {
            if !isInputAttached {
                rebuildEngineGraph(includeInput: true)
            } else {
                micMonitorMixer.volume = enabled ? 1.0 : 0.0
            }
        } else {
            if isInputAttached {
                rebuildEngineGraph(includeInput: false)
            }
        }
    }
}
