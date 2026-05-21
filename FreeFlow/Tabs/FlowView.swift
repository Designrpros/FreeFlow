//
//  FlowView.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 21/05/2026.
//

import SwiftUI
import Combine // Exposes the 'Publishers' type scope for the timer setup

struct FlowView: View {
    @EnvironmentObject private var settings: FlowSettings
    @StateObject private var vm: FlowViewModel
    @StateObject private var audioManager = AudioManager.shared
    @Environment(\.colorScheme) private var colorScheme

    /// Thread-safe explicit initializer ensuring the ViewModel is instantiated on the MainActor
    init() {
        _vm = StateObject(wrappedValue: FlowViewModel())
    }

    private var contentColor: Color {
        colorScheme == .dark ? .white : .black
    }

    /// Dynamically scales font size based on the number of active rows to prevent layout clipping
    private var dynamicFontSize: CGFloat {
        switch settings.numberOfWords {
        case 1...3: return 42
        case 4:    return 38
        case 5:    return 32
        default:   return 28 // 6 words scale target
        }
    }

    /// Dynamically adjusts row spacing depending on stack density
    private var dynamicSpacing: CGFloat {
        settings.numberOfWords > 4 ? 16 : 24
    }

    /// Helper computed property inside the struct to manage the timer interval state
    private var automaticTimer: Publishers.Autoconnect<Timer.TimerPublisher> {
        Timer.publish(every: settings.refreshInterval, on: .main, in: .common).autoconnect()
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Dynamic Lyrics Stack Display Canvas
            Button {
                vm.refresh(using: settings)
            } label: {
                VStack(spacing: dynamicSpacing) {
                    if vm.isLoading {
                        // Visual activity feedback during Datamuse API network calls
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: contentColor))
                            .scaleEffect(1.2)
                    } else if settings.freestyleMode == .wordFlowPlusRhymes && !vm.words.isEmpty {
                        // FOCUS WORD + RHYMES DESIGN LAYOUT
                        
                        // 1. The Big Focus Word Header (Highlighted Anchor)
                        Text(vm.words[0])
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)
                            .lineLimit(1)
                        
                        // 2. Clean Horizontal Divider Line
                        Rectangle()
                            .fill(contentColor.opacity(0.15))
                            .frame(height: 1)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 8)
                        
                        // 3. Vertical Sub-Rhyme Stream
                        VStack(spacing: 12) {
                            ForEach(1..<min(vm.words.count, settings.numberOfWords), id: \.self) { index in
                                Text(vm.words[index])
                                    .font(.system(size: dynamicFontSize, weight: .medium, design: .rounded))
                                    .foregroundColor(contentColor.opacity(0.7))
                                    .lineLimit(1)
                            }
                        }
                    } else {
                        // STANDARD KEYWORDS FLAT LIST LAYOUT
                        VStack(spacing: dynamicSpacing) {
                            ForEach(0..<min(vm.words.count, settings.numberOfWords), id: \.self) { index in
                                Text(vm.words[index])
                                    .font(.system(size: dynamicFontSize, weight: .bold, design: .rounded))
                                    .foregroundColor(contentColor)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 300)
                .padding(.horizontal, 24)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Interactive Media Control Studio Footer Module
            VStack(spacing: 24) {
                HStack(spacing: 40) {
                    // BACKWARD TRACK CONTROL BUTTON
                    Button {
                        navigateTrack(forward: false)
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 22))
                            .foregroundColor(contentColor.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    
                    // UPDATED ACTIVE ELEMENT: Central Live Recording Waveform Canvas
                    VStack(spacing: 0) {
                        LiveAudioWaveformView()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if audioManager.isPlaying {
                            audioManager.stop()
                        } else {
                            audioManager.play(trackName: settings.selectedTrack, using: settings)
                        }
                    }
                    
                    // FORWARD TRACK CONTROL BUTTON
                    Button {
                        navigateTrack(forward: true)
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 22))
                            .foregroundColor(contentColor.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                
                // CONTROL INSTRUCTIONS & PERFORMANCE STATUS STRIP
                VStack(spacing: 6) {
                    Text(audioManager.isPlaying ? "Tap words to shuffle • Tap waveform to stop" : "Tap words to shuffle • Tap waveform to play")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(audioManager.isPlaying ? .blue.opacity(0.8) : contentColor.opacity(0.4))
                    
                    VStack(spacing: 2) {
                        Text(audioManager.isPlaying ? audioManager.activeTrackTitle : settings.selectedTrack)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(contentColor)
                        
                        Text("Studio Production Asset")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(contentColor.opacity(0.4))
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.bottom, 48)
        }        
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { vm.ensureInitialized(using: settings) }
        
        // FIXED: Modernized onChange parameter signatures for iOS 17+ compliance
        .onChange(of: settings.numberOfWords) { oldValue, newValue in
            vm.refresh(using: settings)
        }
        
        .onChange(of: settings.freestyleMode) { oldValue, newValue in
            vm.refresh(using: settings)
        }
        
        .onReceive(automaticTimer) { _ in
            guard settings.refreshStyle.rawValue == "Automatic" else { return }
            vm.refresh(using: settings)
        }
    }
    
    private var currentTrackIndex: Int {
        settings.availableTracks.firstIndex(of: audioManager.isPlaying ? audioManager.activeTrackTitle : settings.selectedTrack) ?? 0
    }
    
    private func navigateTrack(forward: Bool) {
        let totalTracks = settings.availableTracks.count
        guard totalTracks > 0 else { return }
        
        let newIndex: Int
        if forward {
            newIndex = (currentTrackIndex + 1) % totalTracks
        } else {
            newIndex = (currentTrackIndex - 1 + totalTracks) % totalTracks
        }
        
        let nextTrackName = settings.availableTracks[newIndex]
        settings.selectedTrack = nextTrackName
        
        if audioManager.isPlaying {
            audioManager.play(trackName: nextTrackName, using: settings)
        }
    }
}

#Preview {
    FlowView()
        .environmentObject(FlowSettings())
}
