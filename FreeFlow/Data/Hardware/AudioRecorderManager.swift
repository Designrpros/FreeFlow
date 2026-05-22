//
//  AudioRecorderManager.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 22/05/2026.
//

import Foundation
import AVFoundation

final class AudioRecorderManager: NSObject {
    static let shared = AudioRecorderManager()
    
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    
    private override init() {
        super.init()
    }
    
    /// Resolves the unified iCloud or local folder path to keep locations mirrored
    private var targetRecordingDirectory: URL {
        if let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") {
            print("🔊 [AudioRecorderManager] Target storage path: iCloud Ubiquity Container")
            return iCloudURL
        }
        print("🔊 [AudioRecorderManager] Target storage path: Local Device Sandbox Bucket")
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    @MainActor
    func startRecording(settings: FlowSettings) {
        print("🔊 [AudioRecorderManager] Initiating session recording flow...")
        
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.overrideOutputAudioPort(.speaker)
            try session.setActive(true, options: [])
            print("🔊 [AudioRecorderManager] iOS Hardware Audio Session routed to Speakers successfully.")
        } catch {
            print("⚠️ [AudioRecorderManager] CRITICAL: Failed to route audio input channels: \(error.localizedDescription)")
            return
        }
        #endif
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = formatter.string(from: Date())
        
        // FIXED: Record directly into the active shared container destination path
        let fileURL = targetRecordingDirectory.appendingPathComponent("FreeFlow_Session_\(dateString).m4a")
        print("🔊 [AudioRecorderManager] Target Output URL: \(fileURL.path)")
        
        let recordSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: recordSettings)
            let success = audioRecorder?.record() ?? false
            
            if success {
                print("🔊 [AudioRecorderManager] Hardware recording reporting active status: TRUE")
                settings.isRecordingSession = true
                settings.recordingDuration = 0.0
                
                timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak settings] _ in
                    guard let settings = settings else { return }
                    DispatchQueue.main.async {
                        settings.recordingDuration += 1.0
                    }
                }
            } else {
                print("⚠️ [AudioRecorderManager] Hardware failed to write sample buffers to disk location.")
            }
        } catch {
            print("⚠️ [AudioRecorderManager] CRITICAL: Failed to initialize physical hardware recorder: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func stopRecording(settings: FlowSettings) {
        guard let recorder = audioRecorder else {
            print("⚠️ [AudioRecorderManager] Stop requested but no active recorder instance found.")
            return
        }
        
        let savedURL = recorder.url
        recorder.stop()
        audioRecorder = nil
        
        timer?.invalidate()
        timer = nil
        
        print("🔊 [AudioRecorderManager] Recording stopped. File verified on disk size: \(FileManager.default.fileExists(atPath: savedURL.path))")
        
        settings.refreshTracksRoster()
        settings.isRecordingSession = false
        settings.recordingDuration = 0.0
        
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        #endif
    }
}
