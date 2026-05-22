//
//  FlowView.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 22/05/2026.
//

import SwiftUI
import Combine

struct FlowView: View {
    @EnvironmentObject private var settings: FlowSettings
    @StateObject private var vm: FlowViewModel
    @StateObject private var audioManager = AudioManager.shared
    @Environment(\.colorScheme) private var colorScheme

    init() {
        _vm = StateObject(wrappedValue: FlowViewModel())
    }

    private var isDarkMode: Bool {
        if settings.appTheme == .system { return colorScheme == .dark }
        return settings.appTheme == .dark
    }

    private var contentColor: Color { isDarkMode ? .white : .black }

    private var dynamicFontSize: CGFloat {
        switch settings.numberOfWords {
        case 1...3: return 42
        case 4:    return 38
        case 5:    return 32
        default:   return 28
        }
    }

    private var dynamicSpacing: CGFloat { settings.numberOfWords > 4 ? 16 : 24 }

    private var automaticTimer: Publishers.Autoconnect<Timer.TimerPublisher> {
        Timer.publish(every: settings.refreshInterval, on: .main, in: .common).autoconnect()
    }

    // Helper checking current dynamic track storage status
    private var isCurrentTrackLocallyReady: Bool {
        let currentTrackName = audioManager.isPlaying ? audioManager.activeTrackTitle : settings.selectedTrack
        // Built-in assets are always ready
        if settings.factoryTracks.contains(currentTrackName) { return true }
        return LocalStorageManager.shared.isLocalFileReady(fileName: currentTrackName)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            Button {
                vm.refresh(using: settings)
            } label: {
                VStack(spacing: dynamicSpacing) {
                    if vm.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: contentColor))
                            .scaleEffect(1.2)
                    } else if settings.freestyleMode == .wordFlowPlusRhymes && !vm.words.isEmpty {
                        Text(vm.words[0])
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(settings.appAccent.color)
                            .lineLimit(1)
                        
                        Rectangle()
                            .fill(contentColor.opacity(0.15))
                            .frame(height: 1)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 8)
                        
                        VStack(spacing: 12) {
                            ForEach(1..<min(vm.words.count, settings.numberOfWords), id: \.self) { index in
                                Text(vm.words[index])
                                    .font(.system(size: dynamicFontSize, weight: .medium, design: .rounded))
                                    .foregroundColor(contentColor.opacity(0.7))
                                    .lineLimit(1)
                            }
                        }
                    } else {
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
            
            VStack(spacing: 24) {
                HStack(spacing: 40) {
                    Button {
                        navigateTrack(forward: false)
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 22))
                            .foregroundColor(contentColor.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    
                    // Central Live Recording Waveform Canvas
                    VStack(spacing: 0) {
                        if !isCurrentTrackLocallyReady && settings.trackDownloadStates[settings.selectedTrack] == .downloading {
                            // Render a clean loading widget indicator during live streaming cloud download buffers
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: settings.appAccent.color))
                                .frame(width: 48, height: 32)
                        } else {
                            LiveAudioWaveformView()
                                .foregroundColor(audioManager.isPlaying ? settings.appAccent.color : Color(white: 0.5))
                        }
                    }
                    .frame(width: 60, height: 40)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        let activeTrack = settings.selectedTrack
                        if audioManager.isPlaying {
                            audioManager.stop()
                        } else if isCurrentTrackLocallyReady {
                            audioManager.play(trackName: activeTrack, using: settings)
                        } else {
                            // Automatically fire background fetching if the user taps play on an un-downloaded file
                            settings.downloadCloudTrackOnDemand(activeTrack)
                        }
                    }
                    
                    Button {
                        navigateTrack(forward: true)
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 22))
                            .foregroundColor(contentColor.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                
                VStack(spacing: 6) {
                    // Context text label updates dynamically depending on local file caching
                    Group {
                        if !isCurrentTrackLocallyReady {
                            Text(settings.trackDownloadStates[settings.selectedTrack] == .downloading ? "Syncing iCloud instrumental buffers..." : "Instrumental offline • Tap waveform to download")
                        } else {
                            Text(audioManager.isPlaying ? "Tap words to shuffle • Tap waveform to stop" : "Tap words to shuffle • Tap waveform to play")
                        }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(audioManager.isPlaying || !isCurrentTrackLocallyReady ? settings.appAccent.color.opacity(0.8) : contentColor.opacity(0.4))
                    
                    VStack(spacing: 2) {
                        Text(audioManager.isPlaying ? audioManager.activeTrackTitle : settings.selectedTrack)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(contentColor)
                        
                        Text(settings.factoryTracks.contains(audioManager.isPlaying ? audioManager.activeTrackTitle : settings.selectedTrack) ? "Studio Production Asset" : "Custom Cloud Asset")
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
        .background(settings.canvasColor.backgroundColor(isDark: isDarkMode).ignoresSafeArea())
        
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
        
        let newIndex = forward ? (currentTrackIndex + 1) % totalTracks : (currentTrackIndex - 1 + totalTracks) % totalTracks
        let nextTrackName = settings.availableTracks[newIndex]
        settings.selectedTrack = nextTrackName
        
        // Safety: If the user skips to an un-downloaded cloud song while a track is currently playing,
        // stop the audio engine and fire the on-demand cloud fetch sequence safely.
        if !settings.factoryTracks.contains(nextTrackName) && !LocalStorageManager.shared.isLocalFileReady(fileName: nextTrackName) {
            audioManager.stop()
            settings.downloadCloudTrackOnDemand(nextTrackName)
        } else if audioManager.isPlaying {
            audioManager.play(trackName: nextTrackName, using: settings)
        }
    }
}
