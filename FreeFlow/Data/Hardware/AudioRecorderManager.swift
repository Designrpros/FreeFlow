//
//  AudioRecorderManager.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 21/05/2026.
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
    
    @MainActor
    func startRecording(settings: FlowSettings) {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            // Configure iOS audio routing session for concurrent playback + record paths
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            
            // FIXED: Explicitly force the hardware output layer to target the main built-in device speakers
            // instead of dropping audio to the phone earpiece receiver channel during a live microphone stream.
            try session.overrideOutputAudioPort(.speaker)
            
            try session.setActive(true, options: [])
        } catch {
            print("Failed to route hardware audio input channels: \(error.localizedDescription)")
            return
        }
        #endif
        
        // Define unique file name based on current date/time
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = formatter.string(from: Date())
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent("FreeFlow_Session_\(dateString).m4a")
        
        // Setup recording settings (highly compatible AAC compression profile)
        let recordSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: recordSettings)
            audioRecorder?.record()
            
            settings.isRecordingSession = true
            settings.recordingDuration = 0.0
            
            // Start duration tracker cleanly using MainActor execution sweeps
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak settings] _ in
                guard let settings = settings else { return }
                DispatchQueue.main.async {
                    settings.recordingDuration += 1.0
                }
            }
        } catch {
            print("Failed to initialize physical hardware recording: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func stopRecording(settings: FlowSettings) {
        audioRecorder?.stop()
        audioRecorder = nil
        
        timer?.invalidate()
        timer = nil
        
        // Refresh your media file asset roster so this new file shows up in your studio lists
        settings.refreshTracksRoster()
        
        settings.isRecordingSession = false
        settings.recordingDuration = 0.0
        
        #if os(iOS)
        // Reset device routing configuration back to pure consumption media playback
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        #endif
    }
}
