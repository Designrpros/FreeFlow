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
    
    private var timer: Timer?
    private var isRecordingActive = false
    
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
    
    func startRecording(settings: FlowSettings) {
        print("Recorder 🎙️ [Telemetry-Recorder] Tapped active session record control interface button endpoint.")
        guard !isRecordingActive else {
            print("Recorder ⚠️ [Telemetry-Recorder] Start Recording sequence skipped: state indicators verify that an active session take is already operating.")
            return
        }
        
        isRecordingActive = true
        settings.isRecordingSession = true
        settings.recordingDuration = 0.0
        
        // Ensure our single shared audio graph engine has mapped input lanes attached
        if !AudioManager.shared.isInputAttached {
            AudioManager.shared.rebuildEngineGraph(includeInput: true)
        }
        
        guard let recorder = AudioManager.shared.recorder else {
            print("Recorder ⚠️ [Telemetry-Recorder] Terminal Configuration Fault: Unified core engine recorder node missing.")
            isRecordingActive = false
            settings.isRecordingSession = false
            return
        }
        
        do {
            print("Recorder 🎙️ [Telemetry-Recorder] Opening tape stream buffer allocations writing passes...")
            try recorder.record()
            print("Recorder 🎙️ [Telemetry-Recorder] Recording engine successfully active and capturing audio.")
            
            // Fire up the layout UI duration tracking clock
            self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak settings] _ in
                guard let settings = settings else { return }
                settings.recordingDuration += 1.0
            }
        } catch {
            print("Recorder ⚠️ [Telemetry-Recorder] CRITICAL CONFIGURATION FAULT TRIPPED: \(error.localizedDescription)")
            isRecordingActive = false
            settings.isRecordingSession = false
            
            // Re-verify matrix options if start parameters fail
            if !settings.enableMicMonitor {
                AudioManager.shared.rebuildEngineGraph(includeInput: false)
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
        
        guard let recorder = AudioManager.shared.recorder else { return }
        print("Recorder 🎙️ [Telemetry-Recorder] Terminating buffer stream record writing pipeline passes...")
        recorder.stop()
        
        if let targetAudioDataFile = recorder.audioFile {
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
        
        // Re-evaluate input requirements. If monitoring feedback is also off, strip the input lane to hide the orange dot instantly!
        let monitorEnabled = settings.enableMicMonitor
        if !monitorEnabled {
            AudioManager.shared.rebuildEngineGraph(includeInput: false)
        }
        
        print("Recorder 🎙️ [Telemetry-Recorder] Finalizing metadata updates back onto UI main layout views...")
        settings.refreshTracksRoster()
        settings.isRecordingSession = false
        settings.recordingDuration = 0.0
    }
}
