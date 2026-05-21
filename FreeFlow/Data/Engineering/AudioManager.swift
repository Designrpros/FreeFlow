//
//  AudioManager.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 21/05/2026.
//

import Foundation
import AVFoundation
import Combine
#if os(iOS)
import UIKit
#else
import AppKit
#endif

final class AudioManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = AudioManager()
    
    private var playerA: AVAudioPlayer?
    private var playerB: AVAudioPlayer?
    private var isUsingPlayerA = true
    
    private var displayLink: Timer?
    private var settingsReference: FlowSettings?
    private let crossfadeDuration: TimeInterval = 1.0
    private var crossfadeInitiated = false
    
    @Published var isPlaying: Bool = false
    @Published var activeTrackTitle: String = ""
    
    // Combined Master Volume modifier link binding properties
    @Published var masterVolume: Float = 1.0 {
        didSet {
            playerA?.volume = masterVolume
            playerB?.volume = masterVolume
        }
    }
    
    private override init() {
        super.init()
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error.localizedDescription)")
        }
        #endif
    }
    
    private var activePlayer: AVAudioPlayer? {
        return isUsingPlayerA ? playerA : playerB
    }
    
    private var secondaryPlayer: AVAudioPlayer? {
        return isUsingPlayerA ? playerB : playerA
    }
    
    func play(trackName: String, using settings: FlowSettings) {
        self.settingsReference = settings
        stopTimer()
        
        if isPlaying && activeTrackTitle != trackName {
            stop()
        }
        
        guard let url = LocalStorageManager.shared.resolveAudioURL(for: trackName) else {
            print("Audio asset missing: \(trackName).mp3")
            return
        }
        
        do {
            crossfadeInitiated = false
            isUsingPlayerA = true
            
            playerA = try AVAudioPlayer(contentsOf: url)
            playerA?.delegate = self
            playerA?.volume = masterVolume // Applies master slider value on spawn
            
            playerA?.numberOfLoops = settings.loopWithCrossfade ? 0 : ((settings.endBehavior == .loopTrack) ? -1 : 0)
            
            playerA?.prepareToPlay()
            playerA?.play()
            
            isPlaying = true
            activeTrackTitle = trackName
            
            if settings.loopWithCrossfade {
                startMonitoring()
            }
        } catch {
            print("Playback instantiation error: \(error.localizedDescription)")
        }
    }
    
    func stop() {
        stopTimer()
        playerA?.stop()
        playerB?.stop()
        playerA = nil
        playerB = nil
        isPlaying = false
        activeTrackTitle = ""
        crossfadeInitiated = false
    }
    
    private func startMonitoring() {
        displayLink = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.monitorPlaybackTime()
        }
    }
    
    private func stopTimer() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    private func monitorPlaybackTime() {
        guard let mainPlayer = activePlayer, let settings = settingsReference, !crossfadeInitiated else { return }
        
        let timeRemaining = mainPlayer.duration - mainPlayer.currentTime
        
        if timeRemaining <= crossfadeDuration && mainPlayer.duration > crossfadeDuration {
            crossfadeInitiated = true
            triggerCrossfade(using: settings)
        }
    }
    
    private func triggerCrossfade(using settings: FlowSettings) {
        // Validates active track path securely without throwing unused variable warnings
        guard LocalStorageManager.shared.resolveAudioURL(for: activeTrackTitle) != nil else { return }
        
        var nextTrackTitle = activeTrackTitle
        
        if settings.endBehavior == .nextTrack, let currentIndex = settings.availableTracks.firstIndex(of: activeTrackTitle) {
            let nextIndex = (currentIndex + 1) % settings.availableTracks.count
            nextTrackTitle = settings.availableTracks[nextIndex]
            
            DispatchQueue.main.async {
                settings.selectedTrack = nextTrackTitle
            }
        }
        
        guard let nextUrl = LocalStorageManager.shared.resolveAudioURL(for: nextTrackTitle) else { return }
        
        do {
            let nextPlayer = try AVAudioPlayer(contentsOf: nextUrl)
            nextPlayer.delegate = self
            nextPlayer.volume = 0.0
            nextPlayer.numberOfLoops = 0
            nextPlayer.prepareToPlay()
            nextPlayer.play()
            
            if isUsingPlayerA {
                playerB = nextPlayer
            } else {
                playerA = nextPlayer
            }
            
            let originalPlayer = activePlayer
            
            let steps = 15
            let interval = crossfadeDuration / Double(steps)
            var currentStep = 0
            
            Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] fadeTimer in
                guard let self = self else { return }
                currentStep += 1
                let progress = Double(currentStep) / Double(steps)
                
                // Linear calculation tied precisely to the live master volume cap
                originalPlayer?.volume = self.masterVolume * Float(1.0 - progress)
                nextPlayer.volume = self.masterVolume * Float(progress)
                
                if currentStep >= steps {
                    fadeTimer.invalidate()
                    originalPlayer?.stop()
                    
                    self.isUsingPlayerA.toggle()
                    self.crossfadeInitiated = false
                    self.activeTrackTitle = nextTrackTitle
                }
            }
            
        } catch {
            print("Crossfade automation setup failed: \(error.localizedDescription)")
        }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard let settings = settingsReference, !settings.loopWithCrossfade else { return }
        
        isPlaying = false
        if settings.endBehavior == .nextTrack, let currentIndex = settings.availableTracks.firstIndex(of: activeTrackTitle) {
            let nextIndex = (currentIndex + 1) % settings.availableTracks.count
            let nextTrackName = settings.availableTracks[nextIndex]
            
            DispatchQueue.main.async {
                settings.selectedTrack = nextTrackName
                self.play(trackName: nextTrackName, using: settings)
            }
        }
    }
}
