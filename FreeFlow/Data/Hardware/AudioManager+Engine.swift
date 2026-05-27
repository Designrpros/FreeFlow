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
            try session.setCategory(.playback, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
            try session.setActive(true)
            print("📱 [Telemetry-Engine] Application AVAudioSession launched under global high-fidelity Playback tracking profile.")
        } catch {
            print("⚠️ [Telemetry-Engine] Failed pre-warming iOS global session handles: \(error.localizedDescription)")
        }
        #endif
        
        if !engine.avEngine.isRunning {
            DispatchQueue.global(qos: .default).async { [weak self] in
                guard let self = self else { return }
                do {
                    try self.engine.start()
                    print("🔊 [Telemetry-Engine] AudioKit Framework processing matrix successfully activated.")
                } catch {
                    print("⚠️ [Telemetry-Engine] Framework startup pass caught an exception: \(error.localizedDescription)")
                }
            }
        }
    }
    
    internal func setupAudioEngineGraph() {
        if !engine.avEngine.isRunning {
            print("🏗️ [Telemetry-Engine] Graph offline. Pushing structural start pass...")
            try? engine.start()
        }
    }
    
    internal func setupHardwareRouteObservers() {
        print("📡 [Telemetry-Engine] Registering Core Audio framework hardware alteration change listeners...")
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
        
        // Securely forward context changes onto the isolated main-actor recorder singleton instance
        AudioRecorderManager.shared.updateMonitoringVolume(enabled: enabled)
        
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            if enabled {
                try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP, .allowBluetoothHFP])
            } else {
                try session.setCategory(.playback, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
            }
            try session.setActive(true)
            print("📱 [Telemetry-Engine] Live monitoring session adjustment applied successfully.")
        } catch {
            print("⚠️ [Telemetry-Engine] Failed processing dynamic input monitoring route toggles: \(error.localizedDescription)")
        }
        #endif
    }
}
