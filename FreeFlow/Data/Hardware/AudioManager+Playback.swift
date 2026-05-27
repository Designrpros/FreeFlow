//
//  AudioManager+Playback.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 26/05/2026.
//

import Foundation
import AudioKit
import AVFoundation
import Combine

extension AudioManager {
    
    internal func ensureEngineRunning() -> Bool {
        if !engine.avEngine.isRunning {
            print("Playback 🔊 [Telemetry-Playback] Core framework found offline. Pushing runtime activation sequence pass...")
            try? engine.start()
        }
        return engine.avEngine.isRunning
    }
    
    func observeEngineSettings(using settings: FlowSettings) {
        print("Playback 🔊 [Telemetry-Playback] Synchronizing reactive Combine configuration properties maps down into AudioKit filters stack...")
        self.settingsReference = settings
        settingsCancellables.removeAll()
        
        settings.$playbackSpeed
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] targetSpeed in
                guard let self = self else { return }
                let rateValue = Float(targetSpeed)
                print("Playback 🔊 [Telemetry-Playback] Combine Observation: Backing speed multiplier altered context down to \(rateValue)x")
                self.cachedPlaybackRate = rateValue
                if self.timePitch.rate != rateValue {
                    self.timePitch.rate = rateValue
                }
                self.updateNowPlayingPlaybackState(isPlaying: self.isPlaying)
            }
            .store(in: &settingsCancellables)
            
        settings.$pitchShiftSemitones
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] semitones in
                guard let self = self else { return }
                let pitchValue = Float(semitones * 100)
                print("Playback 🔊 [Telemetry-Playback] Combine Observation: Key pitch shifting alteration adjusted to \(semitones) semitones (\(pitchValue) cents)")
                if self.timePitch.pitch != pitchValue {
                    self.timePitch.pitch = pitchValue
                }
            }
            .store(in: &settingsCancellables)
            
        settings.$enableMicMonitor
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                guard let self = self else { return }
                self.toggleHardwareMicMonitor(enabled: enabled)
            }
            .store(in: &settingsCancellables)
    }
    
    func play(trackName: String, using settings: FlowSettings) {
        let now = Date()
        print("Playback 🔊 [Telemetry-Playback] Central Transport play() request initiated for tracking asset title description: '\(trackName)'")
        if now.timeIntervalSince(lastSchedulingPassTimestamp) < 0.35 {
            print("Playback 📝 [Telemetry-Playback] Transport duplicate filtering pass active. Shielding framework from frame bounce jitter loops.")
            return
        }
        lastSchedulingPassTimestamp = now
        
        self.settingsReference = settings
        
        var formattedTrackName = trackName
        if !formattedTrackName.hasSuffix(".mp3") && !formattedTrackName.hasSuffix(".m4a") {
            let clean = formattedTrackName.trimmingCharacters(in: .whitespacesAndNewlines)
            let isFactory = settings.factoryTracks.contains { $0.replacingOccurrences(of: ".mp3", with: "").localizedCaseInsensitiveCompare(clean) == .orderedSame }
            formattedTrackName = isFactory ? "\(clean).mp3" : "\(clean).m4a"
        }
        
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
        try? session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
        
        if activeTrackTitle == formattedTrackName {
            if !isPlaying {
                print("Playback 🔊 [Telemetry-Playback] Target stream path matches loaded asset. Forwarding resume sequence to player.play()...")
                _ = ensureEngineRunning()
                player.play()
                isPlaying = true
                self.updateNowPlayingPlaybackState(isPlaying: true)
            }
            return
        }
        
        let cleanInputName = trackName.replacingOccurrences(of: ".mp3", with: "").replacingOccurrences(of: ".m4a", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        var targetURL: URL? = nil
        let factoryNames = ["Chrome_On_The_Curb", "JazzyFlow", "JazzyFlowDeep", "Late_August_Porch", "Low_Rider_Glide", "Morning_on_the_Deck", "Passing_Thru_Willow_Street", "Under_The_Surface"]
        if factoryNames.contains(where: { $0.lowercased() == cleanInputName.lowercased() }) {
            targetURL = Bundle.main.url(forResource: cleanInputName, withExtension: "mp3")
        } else {
            targetURL = LocalStorageManager.shared.resolveAudioURL(for: formattedTrackName)
        }
        
        guard let url = targetURL else {
            print("Playback ⚠️ [Telemetry-Playback] Terminal Resolve Failure: Local storage URL mapping missing.")
            return
        }
        
        print("Playback 🔊 [Telemetry-Playback] Resolution mapping sequence success metrics: Absolute container path verified at: \(url.path)")
        _ = ensureEngineRunning()
        observeEngineSettings(using: settings)
        
        let playWorkItem = DispatchWorkItem(qos: .utility, flags: .enforceQoS) { [weak self] in
            guard let self = self else { return }
            do {
                print("Playback 🔊 [Telemetry-Playback] [Background Queue] Flushing existing file frame loops descriptions via player.stop()...")
                self.player.stop()
                
                print("Playback 🔊 [Telemetry-Playback] [Background Queue] Invoking synchronous package file reader parsing loop: try player.load(url:)...")
                try self.player.load(url: url)
                
                Thread.sleep(forTimeInterval: 0.15)
                
                DispatchQueue.main.async {
                    print("Playback 🔊 [Telemetry-Playback] Context decode complete. Pushing track transport indicators back onto main queue timeline trackers...")
                    self.timePitch.rate = Float(settings.playbackSpeed)
                    self.timePitch.pitch = Float(settings.pitchShiftSemitones * 100)
                    
                    self.player.play()
                    
                    self.activeTrackTitle = formattedTrackName
                    self.activeTrackDuration = self.player.duration
                    self.isPlaying = true
                    self.trackLoopCounter += 1
                    
                    print("Playback 🔊 [Telemetry-Playback] Advanced AudioKit stream loop wrapper running actively. Title='\(formattedTrackName)', Duration=\(self.player.duration)s")
                    
                    self.synchronizeNowPlayingMetadata(title: formattedTrackName, duration: self.player.duration, isPlaying: true)
                }
            } catch {
                print("Playback ⚠️ [Telemetry-Playback] [Background Queue] Core audio file tracking parse caught an allocation loading exception: \(error)")
            }
        }
        
        DispatchQueue.global(qos: .utility).async(execute: playWorkItem)
    }
    
    func pause() {
        print("Playback ⏸️ [Telemetry-Playback] Central Transport instruction pause() executed. Deflecting blocking loops off Main Thread context...")
        self.isPlaying = false
        self.updateNowPlayingPlaybackState(isPlaying: false)
        
        let pauseWorkItem = DispatchWorkItem(qos: .utility, flags: .enforceQoS) { [weak self] in
            guard let self = self else { return }
            // ✅ FIX: Pause the player node, but leave the global engine running to safeguard active recordings
            self.player.pause()
        }
        
        DispatchQueue.global(qos: .utility).async(execute: pauseWorkItem)
    }
    
    func stop() {
        print("Playback 🛑 [Telemetry-Playback] Central Transport instruction stop() request received. Offloading frame flushes down to background execution lane...")
        self.isPlaying = false
        self.activeTrackTitle = ""
        self.currentProgressPosition = 0.0
        self.activeTrackDuration = 0.0
        self.updateNowPlayingPlaybackState(isPlaying: false)
        
        let stopWorkItem = DispatchWorkItem(qos: .utility, flags: .enforceQoS) { [weak self] in
            guard let self = self else { return }
            // ✅ FIX: Stop the player node, but preserve engine operational registers
            self.player.stop()
            print("Playback 🛑 [Telemetry-Playback] [Background Queue] Finished flushing player nodes.")
        }
        
        DispatchQueue.global(qos: .utility).async(execute: stopWorkItem)
    }
    
    func seekToProgressPercentage(_ percentage: Double) {
        guard activeTrackDuration > 0 else { return }
        let targetTime = percentage * activeTrackDuration
        print("Playback 🔍 [Telemetry-Playback] Timeline index coordinate track request received. Jumping pointer offset directly to: \(targetTime)s (\(percentage * 100)%)")
        player.seek(time: targetTime)
        currentProgressPosition = targetTime
        self.updateNowPlayingPlaybackState(isPlaying: self.isPlaying)
    }
    
    func queryCalculatedTimelineProgressPosition() -> TimeInterval {
        return player.currentTime
    }
    
    internal func advanceToPreviousTrack() {
        guard let settings = settingsReference else { return }
        let currentSearchName = activeTrackTitle.isEmpty ? settings.selectedTrack : activeTrackTitle
        let cleanSearchName = currentSearchName.replacingOccurrences(of: ".mp3", with: "").replacingOccurrences(of: ".m4a", with: "").lowercased()
        
        if let currentIndex = settings.instrumentalBackingTracks.firstIndex(where: { track in
            let cleanTrackName = track.replacingOccurrences(of: ".mp3", with: "").replacingOccurrences(of: ".m4a", with: "").lowercased()
            return cleanTrackName == cleanSearchName
        }) {
            let totalTracks = settings.instrumentalBackingTracks.count
            let prevIndex = (currentIndex - 1 + totalTracks) % totalTracks
            let prevTrackName = settings.instrumentalBackingTracks[prevIndex]
            
            DispatchQueue.main.async {
                print("Playback ⏮️ [Telemetry-Playback] Advancing selection backward to index track: \(prevTrackName)")
                settings.selectedTrack = prevTrackName
                self.play(trackName: prevTrackName, using: settings)
            }
        }
    }
    
    internal func advanceToNextTrack() {
        guard let settings = settingsReference else { return }
        let currentSearchName = activeTrackTitle.isEmpty ? settings.selectedTrack : activeTrackTitle
        let cleanSearchName = currentSearchName.replacingOccurrences(of: ".mp3", with: "").replacingOccurrences(of: ".m4a", with: "").lowercased()
        
        if let currentIndex = settings.instrumentalBackingTracks.firstIndex(where: { track in
            let cleanTrackName = track.replacingOccurrences(of: ".mp3", with: "").replacingOccurrences(of: ".m4a", with: "").lowercased()
            return cleanTrackName == cleanSearchName
        }) {
            let nextIndex = (currentIndex + 1) % settings.instrumentalBackingTracks.count
            let nextTrackName = settings.instrumentalBackingTracks[nextIndex]
            
            DispatchQueue.main.async {
                print("Playback ⏭️ [Telemetry-Playback] Advancing selection forward to index track: \(nextTrackName)")
                settings.selectedTrack = nextTrackName
                self.play(trackName: nextTrackName, using: settings)
            }
        }
    }
}
