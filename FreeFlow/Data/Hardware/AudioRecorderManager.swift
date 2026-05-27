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
    
    private var recorderEngine: AudioEngine?
    private var recorder: NodeRecorder?
    private var timer: Timer?
    private var isRecordingActive = false
    
    // Decoupled mixer links bound directly to the dynamic on-demand recording engine
    private var recordingMixer: Mixer?
    private var monitoringMixer: Mixer?
    
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
        monitoringMixer?.volume = enabled ? 1.0 : 0.0
        print("Recorder 🎛️ [Telemetry-Recorder] Dynamic headphone monitoring lane volume adjusted: \(enabled ? "MUTUAL UNITY" : "MUTED")")
    }
    
    func startRecording(settings: FlowSettings) {
        print("Recorder 🎙️ [Telemetry-Recorder] Tapped active session record control interface button endpoint.")
        guard !isRecordingActive else {
            print("Recorder ⚠️ [Telemetry-Recorder] Start Recording sequence skipped: state indicators verify that an active session take is already operating.")
            return
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = formatter.string(from: Date())
        let fileURL = targetRecordingDirectory.appendingPathComponent("FreeFlow_Session_\(dateString).m4a")
        print("Recorder 🎙️ [Telemetry-Recorder] Creating filesystem target path for final file write streaming output: \(fileURL.path)")
        
        isRecordingActive = true
        settings.isRecordingSession = true
        settings.recordingDuration = 0.0
        
        print("Recorder 🎙️ [Telemetry-Recorder] Offloading session synchronization sequences to an isolated recording engine pipeline...")
        
        Task { @MainActor in
            #if os(iOS)
            print("Recorder 🎙️ [Telemetry-Recorder] Swapping iOS AVAudioSession category options profile parameters layout rules over to allow dynamic Bluetooth Hands-Free Profile links (.allowBluetoothHFP)...")
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP, .allowBluetoothHFP])
                try session.setActive(true, options: .notifyOthersOnDeactivation)
                print("Recorder 🎙️ [Telemetry-Recorder] iOS hardware recording profile hooks completely attached.")
            } catch {
                print("Recorder ⚠️ [Telemetry-Recorder] Dynamic category application failed: \(error.localizedDescription)")
            }
            #endif
            
            do {
                // 1. Initialize a completely independent AudioEngine instance for the recording session
                let engine = AudioEngine()
                self.recorderEngine = engine
                
                let recMixer = Mixer()
                let monMixer = Mixer()
                self.recordingMixer = recMixer
                self.monitoringMixer = monMixer
                
                let safeFrames: AUAudioFrameCount = 4096
                recMixer.avAudioNode.auAudioUnit.maximumFramesToRender = safeFrames
                monMixer.avAudioNode.auAudioUnit.maximumFramesToRender = safeFrames
                
                engine.avEngine.attach(recMixer.avAudioNode)
                engine.avEngine.attach(monMixer.avAudioNode)
                
                // 2. Safely capture hardware input nodes on the secondary engine
                guard let inputNode = engine.input else {
                    throw NSError(domain: "com.freeflow.recorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Microphonic lane track endpoints could not be attached."])
                }
                
                inputNode.avAudioNode.auAudioUnit.maximumFramesToRender = safeFrames
                let hardwareInputFormat = inputNode.avAudioNode.inputFormat(forBus: 0)
                
                print("Recorder 🎙️ [Telemetry-Recorder] Hardware clock resolved: Rate Layout at \(hardwareInputFormat.sampleRate)Hz, Channels: \(hardwareInputFormat.channelCount)")
                
                // 3. Establish routing: Input -> recMixer (Clean capture)
                engine.avEngine.connect(inputNode.avAudioNode, to: recMixer.avAudioNode, format: hardwareInputFormat)
                
                // recMixer -> monMixer (Controlled local playback monitoring feedback loop) -> Engine Output
                let engineOutputFormat = engine.avEngine.outputNode.outputFormat(forBus: 0)
                engine.avEngine.connect(recMixer.avAudioNode, to: monMixer.avAudioNode, format: engineOutputFormat)
                engine.output = monMixer
                
                recMixer.volume = 1.0
                monMixer.volume = settings.enableMicMonitor ? 1.0 : 0.0
                
                print("Recorder 🎙️ [Telemetry-Recorder] Booting isolated recorder graph processing matrix...")
                try engine.start()
                
                // 4. Connect AudioKit's NodeRecorder natively into your recording mixer stage
                let newRecorder = try NodeRecorder(node: recMixer)
                self.recorder = newRecorder
                
                print("Recorder 🎙️ [Telemetry-Recorder] Opening tape stream buffer allocations writing passes: try recorder.record()...")
                try newRecorder.record()
                print("Recorder 🎙️ [Telemetry-Recorder] Isolated recording engine successfully active and capturing audio.")
                
                // 5. Fire up the layout UI duration tracking clock
                self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak settings] _ in
                    guard let settings = settings else { return }
                    settings.recordingDuration += 1.0
                }
            } catch {
                print("Recorder ⚠️ [Telemetry-Recorder] CRITICAL CONFIGURATION FAULT TRIPPED: \(error.localizedDescription)")
                self.cleanupEngine()
                
                self.isRecordingActive = false
                settings.isRecordingSession = false
            }
        }
    }
    
    func stopRecording(settings: FlowSettings) {
        print("Recorder 🎙️ [Telemetry-Recorder] Tapped active session stop record control interface button endpoint.")
        guard isRecordingActive else {
            print("⚠️ [Telemetry-Recorder] Stop recording command aborted: Components are currently idle.")
            return
        }
        
        timer?.invalidate()
        timer = nil
        isRecordingActive = false
        
        print("Recorder 🎙️ [Telemetry-Recorder] Dispatching task to MainActor async teardown context...")
        
        Task { @MainActor in
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
            
            // 6. Tear down and completely destroy the recording engine to release macOS hardware links immediately
            self.cleanupEngine()
            
            #if os(iOS)
            print("Recorder 🎙️ [Telemetry-Recorder] Restoring iOS AVAudioSession high-fidelity output profile categories rules...")
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
            try? session.setActive(true, options: .notifyOthersOnDeactivation)
            #endif
            
            print("Recorder 🎙️ [Telemetry-Recorder] Finalizing metadata updates back onto UI main layout views...")
            settings.refreshTracksRoster()
            settings.isRecordingSession = false
            settings.recordingDuration = 0.0
        }
    }
    
    private func cleanupEngine() {
        recorder?.stop()
        recorder = nil
        recorderEngine?.stop()
        recorderEngine = nil
        recordingMixer = nil
        monitoringMixer = nil
        print("Recorder 🎙️ [Telemetry-Recorder] Recording engine components fully cleared and deallocated.")
    }
}
