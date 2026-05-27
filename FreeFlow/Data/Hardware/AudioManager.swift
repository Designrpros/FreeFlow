//
//  AudioManager.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 23/05/2026.
//

import Foundation
import AVFoundation
import Combine
import AudioKit
import MediaPlayer

final class AudioManager: NSObject, ObservableObject, @unchecked Sendable {
    static let shared = AudioManager()
    
    // --- AUDIOKIT UNIFIED HARDWARE NODES (MUTABLE FOR SEAMLESS DYNAMIC GRAPH REBUILDS) ---
    internal var engine = AudioEngine()
    internal var player = AudioPlayer()
    internal var timePitch: TimePitch!
    internal var mixer = Mixer()
    
    // --- DYNAMIC HARDWARE LATCH REGISTERS ---
    internal var isInputAttached = false
    internal var micMonitorMixer = Mixer()
    internal var recorder: NodeRecorder?
    
    // --- ECOSYSTEM CROSS-COMPATIBILITY PUBLISHED TARGETS ---
    @Published var isPlaying: Bool = false
    @Published var activeTrackTitle: String = ""
    @Published var currentProgressPosition: TimeInterval = 0.0
    @Published var activeTrackDuration: TimeInterval = 0.0
    @Published var trackLoopCounter: Int = 0
    @Published var isSeekingTimeline = false
    
    // Lockscreen metadata helper registers
    internal var cachedPlaybackRate: Float = 1.0
    
    internal var useFallbackEngine = false
    internal var settingsReference: FlowSettings?
    internal var settingsCancellables = Set<AnyCancellable>()
    internal var lastSchedulingPassTimestamp: Date = Date.distantPast
    
    @Published var masterVolume: Float = 1.0 {
        didSet {
            print("🎛️ [Telemetry-AudioManager] Master volume slider configuration mutated to value parameter: \(masterVolume)")
            mixer.volume = masterVolume
        }
    }
    
    private override init() {
        print("🔊 [Telemetry-AudioManager] Initializing Global AudioKit Core Shared Singleton Instance Wrapper.")
        super.init()
        
        // Establish our base time pitch structural nodes
        self.timePitch = TimePitch(player)
        mixer.addInput(timePitch)
        engine.output = mixer
        
        setupHardwareRouteObservers()
        setupRemoteCommandCenter()
    }
}
