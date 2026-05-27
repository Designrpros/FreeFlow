//
//  AudioManager+Playback.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 27/05/2026.
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
                
                if let lastTimestamp = self.lastPlayAbsoluteTimestamp {
                    let elapsed = Date().timeIntervalSince(lastTimestamp) * Double(self.cachedPlaybackRate)
                    self.baseSeekTime += elapsed
                    self.lastPlayAbsoluteTimestamp = Date()
                }
                
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
            
        settings.$endBehavior
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] behavior in
                guard let self = self else { return }
                print("Playback 🔊 [Telemetry-Playback] Combine Observation: End behavior adjusted to \(behavior.rawValue)")
                self.configurePlaybackEndBehavior(using: settings)
            }
            .store(in: &settingsCancellables)
            
        // Reduced frequency to 0.3 seconds
        Timer.publish(every: 0.3, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.monitorTrackCompletionState()
            }
            .store(in: &settingsCancellables)
    }
    
    internal func configurePlaybackEndBehavior(using settings: FlowSettings) {
        player.isLooping = false
        player.completionHandler = nil
        print("Playback 🔊 [Telemetry-Playback] Baseline hardware loop attributes registered safely.")
    }
    
    private func monitorTrackCompletionState() {
        // Ignore completion for 2 seconds after a seek
        guard Date().timeIntervalSince(lastSeekTime) > 3.0 else { return }
        guard isPlaying && !isSeekingTimeline else { return }
        guard let _ = settingsReference else { return }
        guard activeTrackDuration > 0 else { return }
        
        let currentTime = queryCalculatedTimelineProgressPosition()
        guard currentTime > 0.5 else { return }
        
        let isNearEnd = currentTime >= (activeTrackDuration - 0.5) // Increased threshold
        if isNearEnd {
            executeAutoAdvanceOrLoop()
        }
    }
    
    internal func executeAutoAdvanceOrLoop() {
        // Block auto-advance if a seek happened recently
        guard Date().timeIntervalSince(lastSeekTime) > 2.0 else {
            print("Playback ⏭️ [Telemetry-Playback] Auto-advance blocked (recent seek)")
            return
        }
        
        guard let settings = settingsReference else { return }
        
        self.isSeekingTimeline = true
        seekSessionID += 1
        let currentID = seekSessionID
        
        let isUserRecordingFile = activeTrackTitle.lowercased().hasSuffix(".m4a")
        
        if settings.endBehavior == .loopTrack && !isUserRecordingFile {
            print("Playback 🔁 [Telemetry-Playback] Software loop boundary hit. Rewinding player timeline register...")
            player.pause()
            player.seek(time: 0.0)
            
            self.baseSeekTime = 0.0
            self.lastPlayAbsoluteTimestamp = Date()
            
            _ = ensureEngineRunning()
            player.play()
            self.trackLoopCounter += 1
            
            DispatchQueue.main.async {
                self.updateNowPlayingPlaybackState(isPlaying: true)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                if self.seekSessionID == currentID {
                    self.isSeekingTimeline = false
                }
            }
        } else {
            print("Playback ⏭️ [Telemetry-Playback] Software completion boundary hit. Terminating or advancing sequence context...")
            self.isPlaying = false
            self.player.stop()
            
            if isUserRecordingFile {
                self.activeTrackTitle = ""
                self.baseSeekTime = 0.0
                self.lastPlayAbsoluteTimestamp = nil
                self.isSeekingTimeline = false
                DispatchQueue.main.async {
                    self.updateNowPlayingPlaybackState(isPlaying: false)
                }
            } else {
                self.advanceToNextTrack()
            }
        }
    }
    
    func play(trackName: String, using settings: FlowSettings) {
        let now = Date()
        print("Playback 🔊 [Telemetry-Playback] Central Transport play() request initiated for tracking asset title description: '\(trackName)'")
        if now.timeIntervalSince(lastSchedulingPassTimestamp) < 0.35 {
            print("Playback 📝 [Telemetry-Playback] Transport duplicate filtering pass active. Shielding framework from frame bounce jitter loops.")
            return
        }
        lastSchedulingPassTimestamp = now
        
        self.isSeekingTimeline = true
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
                
                self.lastPlayAbsoluteTimestamp = Date()
                
                player.play()
                isPlaying = true
                self.isSeekingTimeline = false
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
            print("Playback ⚠️ [Telemetry-Playback] Terminal Box Failure: Local storage URL mapping missing.")
            self.isSeekingTimeline = false
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
                    
                    self.configurePlaybackEndBehavior(using: settings)
                    
                    self.baseSeekTime = 0.0
                    self.lastPlayAbsoluteTimestamp = Date()
                    
                    self.player.play()
                    
                    self.activeTrackTitle = formattedTrackName
                    self.activeTrackDuration = self.player.duration
                    self.isPlaying = true
                    self.trackLoopCounter += 1
                    
                    self.isSeekingTimeline = false
                    
                    print("Playback 🔊 [Telemetry-Playback] Advanced AudioKit stream loop wrapper running actively. Title='\(formattedTrackName)', Duration=\(self.player.duration)s")
                    
                    self.synchronizeNowPlayingMetadata(title: formattedTrackName, duration: self.player.duration, isPlaying: true)
                }
            } catch {
                print("Playback ⚠️ [Telemetry-Playback] [Background Queue] Core audio file tracking parse caught an allocation loading exception: \(error)")
                DispatchQueue.main.async {
                    self.isSeekingTimeline = false
                }
            }
        }
        
        DispatchQueue.global(qos: .utility).async(execute: playWorkItem)
    }
    
    func pause() {
        print("Playback ⏸️ [Telemetry-Playback] Central Transport instruction pause() executed. Deflecting blocking loops off Main Thread context...")
        
        if let lastTimestamp = lastPlayAbsoluteTimestamp {
            let elapsed = Date().timeIntervalSince(lastTimestamp) * Double(cachedPlaybackRate)
            baseSeekTime += elapsed
        }
        lastPlayAbsoluteTimestamp = nil
        
        self.isPlaying = false
        self.updateNowPlayingPlaybackState(isPlaying: false)
        
        self.player.pause()
    }
    
    func stop() {
        print("Playback 🛑 [Telemetry-Playback] Central Transport instruction stop() request received. Offloading frame flushes down to background execution lane...")
        self.isPlaying = false
        self.activeTrackTitle = ""
        self.currentProgressPosition = 0.0
        self.activeTrackDuration = 0.0
        
        self.baseSeekTime = 0.0
        self.lastPlayAbsoluteTimestamp = nil
        
        self.updateNowPlayingPlaybackState(isPlaying: false)
        
        self.player.stop()
        print("Playback 🛑 [Telemetry-Playback] Finished flushing player nodes.")
    }
    
    func startSeekTransaction() {
        pendingSeekWorkItem?.cancel()
        pendingSeekWorkItem = nil
        seekSessionID += 1
    }
    
    func seekToProgressPercentage(_ percentage: Double) {
        guard activeTrackDuration > 0 else { return }
        let targetTime = percentage * activeTrackDuration
        print("🔍 Hard seek to \(targetTime)s (\(percentage * 100)%)")
        
        // Cancel any pending seek
        pendingSeekWorkItem?.cancel()
        
        seekSessionID += 1
        let currentID = seekSessionID
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, self.seekSessionID == currentID else { return }
            
            let wasPlaying = self.isPlaying
            
            // Full stop – clears all internal state
            self.player.stop()
            
            // Perform seek on a clean player
            self.player.seek(time: targetTime)
            
            // Update tracking
            self.currentProgressPosition = targetTime
            self.isSeekingTimeline = true
            self.lastSeekTime = Date()
            
            if wasPlaying {
                _ = self.ensureEngineRunning()
                // Restart playback
                self.player.play()
                self.lastPlayAbsoluteTimestamp = Date()
                let actual = self.player.currentTime
                self.baseSeekTime = actual
                self.currentProgressPosition = actual
            } else {
                self.lastPlayAbsoluteTimestamp = nil
                self.baseSeekTime = targetTime
            }
            
            self.updateNowPlayingPlaybackState(isPlaying: wasPlaying)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.isSeekingTimeline = false
            }
        }
        
        pendingSeekWorkItem = workItem
        // Longer debounce – 0.4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: workItem)
    }
    
    func queryCalculatedTimelineProgressPosition() -> TimeInterval {
        if isSeekingTimeline {
            return currentProgressPosition
        }
        let position = player.currentTime
        return max(0.0, min(activeTrackDuration, position))
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
        
        guard Date().timeIntervalSince(lastSeekTime) > 3.0 else {
            print("Playback ⏭️ [Telemetry-Playback] Auto-advance blocked (recent seek)")
            return
        }
        
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
