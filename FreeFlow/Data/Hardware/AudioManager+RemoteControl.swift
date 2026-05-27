//
//  AudioManager+RemoteControl.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 26/05/2026.
//

import Foundation
import MediaPlayer
#if os(iOS)
import UIKit
#endif

extension AudioManager {
    
    internal func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        print("🎛️ [Telemetry-Remote] Binding system control endpoints inside MPRemoteCommandCenter infrastructure hooks...")
        
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true
        
        #if os(iOS)
        DispatchQueue.main.async {
            print("🎛️ [Telemetry-Remote] Registering application instance for lockscreen events: beginReceivingRemoteControlEvents()")
            UIApplication.shared.beginReceivingRemoteControlEvents()
        }
        #endif
        
        commandCenter.playCommand.addTarget { [weak self] event in
            print("🎛️ [Headset Hardware Intercept] Play button command intercepted from hardware/lockscreen widget.")
            guard let self = self else { return .noSuchContent }
            
            // Execute on MainActor to securely access settings blocks safely
            let isPlayingCaptured = self.isPlaying
            let trackCaptured = self.settingsReference?.selectedTrack
            let settingsCaptured = self.settingsReference
            
            if !isPlayingCaptured {
                if let track = trackCaptured, let settings = settingsCaptured {
                    print("🎛️ [Headset Hardware Intercept] Triggering transport stream play sequence for: \(track)")
                    Task { @MainActor in
                        self.play(trackName: track, using: settings)
                    }
                    return .success
                }
            }
            return .commandFailed
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] event in
            print("🎛️ [Headset Hardware Intercept] Pause button command intercepted from hardware/lockscreen widget.")
            guard let self = self else { return .noSuchContent }
            if self.isPlaying {
                print("🎛️ [Headset Hardware Intercept] Executing pause transport pipeline request...")
                self.pause()
                return .success
            }
            return .commandFailed
        }
        
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] event in
            print("🎛️ [Headset Hardware Intercept] Toggle Play/Pause button command intercepted from hardware/lockscreen widget.")
            guard let self = self else { return .noSuchContent }
            
            let isPlayingCaptured = self.isPlaying
            let trackCaptured = self.settingsReference?.selectedTrack
            let settingsCaptured = self.settingsReference
            
            if isPlayingCaptured {
                print("🎛️ [Headset Hardware Intercept] Track active. Directing pause pass...")
                self.pause()
            } else {
                if let track = trackCaptured, let settings = settingsCaptured {
                    print("🎛️ [Headset Hardware Intercept] Track idle. Directing play pass for: \(track)")
                    Task { @MainActor in
                        self.play(trackName: track, using: settings)
                    }
                }
            }
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] event in
            print("🎛️ [Headset Hardware Intercept] Skip Next button command intercepted from hardware/lockscreen widget.")
            guard let self = self else { return .noSuchContent }
            Task { @MainActor in
                self.advanceToNextTrack()
            }
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] event in
            print("🎛️ [Headset Hardware Intercept] Skip Back button command intercepted from hardware/lockscreen widget.")
            guard let self = self else { return .noSuchContent }
            Task { @MainActor in
                self.advanceToPreviousTrack()
            }
            return .success
        }
        
        var baseInfo = [String: Any]()
        baseInfo[MPMediaItemPropertyTitle] = "Tap to Freestyle"
        baseInfo[MPMediaItemPropertyArtist] = "FreeFlow"
        baseInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = baseInfo
        
        #if os(macOS)
        MPNowPlayingInfoCenter.default().playbackState = .paused
        #endif
        
        print("🎛️ [Telemetry-Remote] Headset remote command targets completely attached with baseline anchors.")
    }
    
    internal func synchronizeNowPlayingMetadata(title: String, duration: TimeInterval, isPlaying: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("🎛️ [Telemetry-Remote] Transmitting full metadata sync pass down to system lockscreen widget: Title='\(title)', Duration=\(duration)s")
            
            let cleanTitle = title.replacingOccurrences(of: ".mp3", with: "")
                                  .replacingOccurrences(of: ".m4a", with: "")
                                  .replacingOccurrences(of: "_", with: " ")
            
            var nowPlayingInfo = [String: Any]()
            nowPlayingInfo[MPMediaItemPropertyTitle] = cleanTitle
            nowPlayingInfo[MPMediaItemPropertyArtist] = "FreeFlow"
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = self.queryCalculatedTimelineProgressPosition()
            
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? self.cachedPlaybackRate : 0.0
            nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] = self.cachedPlaybackRate
            
            #if os(iOS)
            if let logoImage = UIImage(named: "LockScreenLogo") ?? UIImage(named: "AppIcon") {
                let artwork = MPMediaItemArtwork(boundsSize: logoImage.size) { _ in return logoImage }
                nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
            }
            #endif
            
            MPRemoteCommandCenter.shared().playCommand.isEnabled = true
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
            
            #if os(macOS)
            MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
            #endif
            
            print("🎛️ [Telemetry-Remote] Lockscreen notification data map synchronized successfully.")
        }
    }
    
    internal func updateNowPlayingPlaybackState(isPlaying: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let elapsed = self.queryCalculatedTimelineProgressPosition()
            print("🎛️ [Telemetry-Remote] Refreshing active timeline transport markers down to system widget interfaces: Position=\(elapsed)s, isPlaying=\(isPlaying)")
            
            if var currentInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo {
                // ✅ FIXED: Replaced non-existent variable with standard proper framework key tracking coordinates
                currentInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
                currentInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? self.cachedPlaybackRate : 0.0
                MPNowPlayingInfoCenter.default().nowPlayingInfo = currentInfo
            }
            
            #if os(macOS)
            MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
            #endif
        }
    }
}
