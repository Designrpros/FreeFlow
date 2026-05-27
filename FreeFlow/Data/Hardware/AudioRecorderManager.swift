//
//  AudioRecorderManager.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 22/05/2026.
//

import Foundation
import AudioKit
import AVFoundation

@MainActor
final class AudioRecorderManager: NSObject, @unchecked Sendable {
    static let shared = AudioRecorderManager()
    
    private var recorder: NodeRecorder?
    private var timer: Timer?
    private var isRecordingActive = false
    
    // TWIN-MIXER CONVERSION SHIELD: Separates pristine recording input from local headphone monitoring loops
    private let recordingMixer = Mixer()
    private let monitoringMixer = Mixer()
    
    private override init() {
        super.init()
        print("Recorder 🔊 [Telemetry-Recorder] Instantiating Audio Recorder Management Component.")
    }
    
    private var targetRecordingDirectory: URL {
        if let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") {
            print("Recorder 🔊 [Telemetry-Recorder] Target container validation check: iCloud storage path endpoint verified successfully.")
            return iCloudURL
        }
        print("Recorder 🔊 [Telemetry-Recorder] Target container validation check: Application Document Sandbox directory bucket storage path verified.")
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    /// Public access endpoint allowing AudioManager to dynamically toggle headphone feedback volumes mid-session
    func updateMonitoringVolume(enabled: Bool) {
        recordingMixer.volume = 1.0 // Safeguard recording lane at absolute unity gain
        monitoringMixer.volume = enabled ? 1.0 : 0.0
        print("Recorder 🎛️ [Telemetry-Recorder] Dynamic headphone monitoring lane volume adjusted: \(enabled ? "MUTUAL UNITY" : "MUTED")")
    }
    
    func startRecording(settings: FlowSettings) {
        print("Recorder 🎙️ [Telemetry-Recorder] Tapped active session record control interface button endpoint.")
        guard !isRecordingActive else {
            print("Recorder ⚠️ [Telemetry-Recorder] Start Recording sequence skipped: state indicators verify that an active session take is already operating.")
            return
        }
        
        let manager = AudioManager.shared
        let wasPlayingMusic = manager.isPlaying
        print("Recorder 🎙️ [Telemetry-Recorder] Core status metrics verification step: wasPlayingMusic flag value state captures as = \(wasPlayingMusic)")
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = formatter.string(from: Date())
        let fileURL = targetRecordingDirectory.appendingPathComponent("FreeFlow_Session_\(dateString).m4a")
        print("Recorder 🎙️ [Telemetry-Recorder] Creating filesystem target path for final file write streaming output: \(fileURL.path)")
        
        isRecordingActive = true
        settings.isRecordingSession = true
        settings.recordingDuration = 0.0
        
        print("Recorder 🎙️ [Telemetry-Recorder] Offloading session synchronization sequences to MainActor async task pipeline...")
        
        Task { @MainActor in
            // Temporarily suspend observers during engine configuration to prevent thread-racing configuration overlaps
            NotificationCenter.default.removeObserver(manager, name: .AVAudioEngineConfigurationChange, object: manager.engine.avEngine)
            
            #if os(iOS)
            print("Recorder 🎙️ [Telemetry-Recorder] Swapping iOS AVAudioSession category options profile parameters layout rules over to allow dynamic Bluetooth Hands-Free Profile links (.allowBluetoothHFP)...")
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
                try session.setActive(true, options: .notifyOthersOnDeactivation)
                print("Recorder 🎙️ [Telemetry-Recorder] iOS hardware recording profile hooks completely attached.")
            } catch {
                print("Recorder ⚠️ [Telemetry-Recorder] Dynamic category application failed: \(error.localizedDescription)")
            }
            #endif
            
            if wasPlayingMusic {
                print("Recorder 🎙️ [Telemetry-Recorder] Pausing audio player output lines to secure underlying layout marker anchor calculations registers...")
                manager.player.pause()
            }
            
            print("Recorder 🎙️ [Telemetry-Recorder] Halting engine registers to permit structural graph connection re-allocations...")
            manager.engine.stop()
            
            print("Recorder 🎙️ [Telemetry-Recorder] Injecting hardware AU rendering frame capacity ceilings into unallocated registers...")
            let safeFrames: AUAudioFrameCount = 4096
            self.recordingMixer.avAudioNode.auAudioUnit.maximumFramesToRender = safeFrames
            self.monitoringMixer.avAudioNode.auAudioUnit.maximumFramesToRender = safeFrames
            manager.mixer.avAudioNode.auAudioUnit.maximumFramesToRender = safeFrames
            manager.engine.avEngine.outputNode.auAudioUnit.maximumFramesToRender = safeFrames
            
            print("Recorder 🎙️ [Telemetry-Recorder] Entering hardware category transition route change stabilization pause sleep framework for 650ms...")
            try? await Task.sleep(nanoseconds: 650 * 1_000_000)
            
            do {
                if self.recordingMixer.avAudioNode.engine == nil {
                    manager.engine.avEngine.attach(self.recordingMixer.avAudioNode)
                }
                if self.monitoringMixer.avAudioNode.engine == nil {
                    manager.engine.avEngine.attach(self.monitoringMixer.avAudioNode)
                }
                
                // Establish our fixed standard high-fidelity target format
                let standardStereoFormat = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2) ?? manager.engine.avEngine.outputNode.outputFormat(forBus: 0)
                
                // Anchor our structural mixer blocks downstream into primary audio filters path mixer
                manager.engine.avEngine.connect(self.recordingMixer.avAudioNode, to: self.monitoringMixer.avAudioNode, format: standardStereoFormat)
                manager.engine.avEngine.connect(self.monitoringMixer.avAudioNode, to: manager.mixer.avAudioNode, format: standardStereoFormat)
                
                self.recordingMixer.volume = 1.0
                self.monitoringMixer.volume = settings.enableMicMonitor ? 1.0 : 0.0
                
                print("Recorder 🎙️ [Telemetry-Recorder] Querying input node configuration maps while graph layout is unallocated...")
                let baselineInputNode = manager.engine.input
                
                guard let inputNode = baselineInputNode else {
                    throw NSError(domain: "com.freeflow.recorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Microphonic lane track endpoints could not be attached."])
                }
                
                inputNode.avAudioNode.auAudioUnit.maximumFramesToRender = safeFrames
                
                // ✅ FIX: Connect the input node to the recording mixer using the fixed 48kHz standardStereoFormat.
                // This forces AVAudioEngine to handle the AirPods sample rate upsampling internally,
                // feeding the recording mixer a clean 48kHz stream and completely eliminating error -50.
                manager.engine.avEngine.connect(inputNode.avAudioNode, to: self.recordingMixer.avAudioNode, format: standardStereoFormat)
                
                print("Recorder 🎙️ [Telemetry-Recorder] Re-booting graph context configurations via try engine.start()...")
                try manager.engine.start()
                
                print("Recorder 🎙️ [Telemetry-Recorder] Waiting for Bluetooth hardware stream profile stabilization...")
                try? await Task.sleep(nanoseconds: 450 * 1_000_000)
                
                var hardwareInputFormat = inputNode.avAudioNode.inputFormat(forBus: 0)
                var syncAttempts = 0
                let maxSyncAttempts = 12
                
                while (hardwareInputFormat.sampleRate == 0 || hardwareInputFormat.channelCount == 0) && syncAttempts < maxSyncAttempts {
                    syncAttempts += 1
                    print("Recorder 🎙️ [Telemetry-Recorder] Hardware input clock unresolved (Attempt \(syncAttempts)/\(maxSyncAttempts)). Polling driver registers...")
                    try? await Task.sleep(nanoseconds: 150 * 1_000_000)
                    hardwareInputFormat = inputNode.avAudioNode.inputFormat(forBus: 0)
                }
                
                print("Recorder 🎙️ [Telemetry-Recorder] Hardware clock synchronization finalized: Resolved Stable Microphonic Rate Layout at: \(hardwareInputFormat.sampleRate)Hz, Channels: \(hardwareInputFormat.channelCount)")
                
                guard hardwareInputFormat.sampleRate > 0 && hardwareInputFormat.channelCount > 0 else {
                    throw NSError(domain: "com.freeflow.recorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Hardware device driver returned completely invalid uninitialized format bounds matrix metrics blocks."])
                }
                
                print("Recorder 🎙️ [Telemetry-Recorder] Instantiating high-level AudioKit NodeRecorder handle targeted at the isolated recordingMixer...")
                self.recorder = try NodeRecorder(node: self.recordingMixer)
                
                print("Recorder 🎙️ [Telemetry-Recorder] Opening tape stream buffer allocations writing passes: try recorder.record()...")
                try self.recorder?.record()
                print("Recorder 🎙️ [Telemetry-Recorder] AudioKit wrapper custom NodeRecorder framework subcomponent successfully active and streaming.")
                
                manager.setupHardwareRouteObservers()
                
                if wasPlayingMusic {
                    print("Recorder 🎙️ [Telemetry-Recorder] Restoring backing tracks playback rendering nodes context parameters loops passes.")
                    manager.play(trackName: settings.selectedTrack, using: settings)
                }
                
                print("Recorder 🎙️ [Telemetry-Recorder] Re-routing control notifications state update ticks metrics back onto Main interface timeline context frames queues thread...")
                self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak settings] _ in
                    guard let settings = settings else { return }
                    settings.recordingDuration += 1.0
                }
            } catch {
                print("Recorder ⚠️ [Telemetry-Recorder] CRITICAL CONFIGURATION FAULT TRIPPED: \(error.localizedDescription)")
                self.recorder?.stop()
                self.recorder = nil
                
                manager.setupHardwareRouteObservers()
                
                self.isRecordingActive = false
                settings.isRecordingSession = false
                
                if wasPlayingMusic {
                    manager.play(trackName: settings.selectedTrack, using: settings)
                }
            }
        }
    }
    
    func stopRecording(settings: FlowSettings) {
        print("Recorder 🎙️ [Telemetry-Recorder] Tapped active session stop record control interface button endpoint.")
        guard isRecordingActive else {
            print("⚠️ [Telemetry-Recorder] Stop recording command aborted: State machine verification maps confirm recording components are currently idle.")
            return
        }
        
        timer?.invalidate()
        timer = nil
        isRecordingActive = false
        
        let manager = AudioManager.shared
        let wasPlayingMusic = manager.isPlaying
        
        print("Recorder 🎙️ [Telemetry-Recorder] Dispatching task to MainActor async teardown context...")
        
        Task { @MainActor in
            NotificationCenter.default.removeObserver(manager, name: .AVAudioEngineConfigurationChange, object: manager.engine.avEngine)
            
            print("Recorder 🎙️ [Telemetry-Recorder] Terminating buffer stream record writing pipeline passes...")
            self.recorder?.stop()
            
            if let targetAudioDataFile = self.recorder?.audioFile {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd_HHmmss"
                let cleanFileName = "FreeFlow_Session_\(formatter.string(from: Date())).m4a"
                let cleanDestinationURL = self.targetRecordingDirectory.appendingPathComponent(cleanFileName)
                
                print("Recorder 🎙️ [Telemetry-Recorder] Transpiling temporary data blocks track container over to final destination: \(cleanDestinationURL.path)")
                
                do {
                    if FileManager.default.fileExists(atPath: cleanDestinationURL.path) {
                        try FileManager.default.removeItem(at: cleanDestinationURL)
                    }
                    try FileManager.default.moveItem(at: targetAudioDataFile.url, to: cleanDestinationURL)
                    print("Recorder 🎙️ [Telemetry-Recorder] SUCCESS: Studio performance file moved cleanly to permanent documents roster.")
                } catch {
                    print("Recorder ⚠️ [Telemetry-Recorder] DISK TRANSACTION FAILED: \(error.localizedDescription)")
                }
            }
            
            self.recorder = nil
            
            print("Recorder 🎙️ [Telemetry-Recorder] Halting engine context changes safely...")
            manager.engine.stop()
            
            #if os(iOS)
            print("Recorder 🎙️ [Telemetry-Recorder] Restoring iOS AVAudioSession high-fidelity output profile categories rules...")
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
            try? session.setActive(true, options: .notifyOthersOnDeactivation)
            #endif
            
            do {
                print("Recorder 🎙️ [Telemetry-Recorder] Re-booting core engine components maps graph onto baseline playback criteria...")
                try manager.engine.start()
            } catch {
                print("Recorder 🎙️ ⚠️ [Teardown Context] Core engine restart cycle optimization failed: \(error.localizedDescription)")
            }
            
            manager.setupHardwareRouteObservers()
            
            if wasPlayingMusic {
                print("Recorder 🎙️ [Telemetry-Recorder] Automatically re-triggering active backing instrumental soundtrack streams layout context...")
                manager.play(trackName: settings.selectedTrack, using: settings)
            }
            
            print("Recorder 🎙️ [Telemetry-Recorder] Finalizing metadata updates back onto UI main layout views loop thread context tracking matrix maps.")
            settings.refreshTracksRoster()
            settings.isRecordingSession = false
            settings.recordingDuration = 0.0
        }
    }
}
