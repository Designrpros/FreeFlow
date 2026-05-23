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

    @State private var isScrubbing: Bool = false
    @State private var localScrubValue: Double = 0.0

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

    private var isCurrentTrackLocallyReady: Bool {
        let currentTrackName = audioManager.isPlaying ? audioManager.activeTrackTitle : settings.selectedTrack
        
        let cleanCurrentName = currentTrackName.replacingOccurrences(of: ".mp3", with: "")
                                              .replacingOccurrences(of: ".m4a", with: "")
                                              .lowercased()
        
        let isFactoryAsset = settings.factoryTracks.contains { factoryTrack in
            let cleanFactoryName = factoryTrack.replacingOccurrences(of: ".mp3", with: "")
                                               .replacingOccurrences(of: ".m4a", with: "")
                                               .lowercased()
            return cleanFactoryName == cleanCurrentName
        }
        
        if isFactoryAsset { return true }
        return LocalStorageManager.shared.isLocalFileReady(fileName: currentTrackName)
    }

    // 🚀 FIXED: Helper handles text mutations to dynamically strip file extensions before displaying the layout
    private var cleanDisplayTrackTitle: String {
        let rawTrack = audioManager.isPlaying ? audioManager.activeTrackTitle : settings.selectedTrack
        return rawTrack.replacingOccurrences(of: ".mp3", with: "")
                       .replacingOccurrences(of: ".m4a", with: "")
                       .replacingOccurrences(of: "_", with: " ")
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
                                if vm.words.indices.contains(index) {
                                    Text(vm.words[index])
                                        .font(.system(size: dynamicFontSize, weight: .medium, design: .rounded))
                                        .foregroundColor(contentColor.opacity(0.7))
                                        .lineLimit(1)
                                }
                            }
                        }
                    } else {
                        VStack(spacing: dynamicSpacing) {
                            ForEach(0..<min(vm.words.count, settings.numberOfWords), id: \.self) { index in
                                if vm.words.indices.contains(index) {
                                    Text(vm.words[index])
                                        .font(.system(size: dynamicFontSize, weight: .bold, design: .rounded))
                                        .foregroundColor(contentColor)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
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
            
            // TIMELINE TIMESTAMP PROGRESS CONTROL MODULE CARD
            if audioManager.activeTrackDuration > 0 {
                VStack(spacing: 4) {
                    Slider(
                        value: Binding(
                            get: {
                                if isScrubbing { return localScrubValue }
                                guard audioManager.activeTrackDuration > 0 else { return 0.0 }
                                return audioManager.currentProgressPosition / audioManager.activeTrackDuration
                            },
                            set: { newValue in
                                if !isScrubbing { isScrubbing = true }
                                localScrubValue = newValue
                            }
                        ),
                        in: 0.0...1.0,
                        onEditingChanged: { editing in
                            if !editing {
                                audioManager.seekToProgressPercentage(localScrubValue)
                                isScrubbing = false
                            }
                        }
                    )
                    .tint(settings.appAccent.color)
                    .controlSize(.small)
                    .padding(.horizontal, 32)
                    
                    HStack {
                        Text(formatTimeLabel(isScrubbing ? (localScrubValue * audioManager.activeTrackDuration) : audioManager.currentProgressPosition))
                        Spacer()
                        Text(formatTimeLabel(audioManager.activeTrackDuration))
                    }
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(contentColor.opacity(0.4))
                    .padding(.horizontal, 36)
                }
                .padding(.bottom, 12)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: audioManager.activeTrackDuration)
            }
            
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
                    
                    VStack(spacing: 0) {
                        if !isCurrentTrackLocallyReady && settings.trackDownloadStates[settings.selectedTrack] == .downloading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: settings.appAccent.color))
                                .frame(width: 48, height: 32)
                        } else {
                            LiveAudioWaveformView(
                                isPlaying: audioManager.isPlaying,
                                isSeeking: audioManager.isSeekingTimeline
                            )
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
                        // 🚀 FIXED: Displays clean display string without file extension types
                        Text(cleanDisplayTrackTitle)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(contentColor)
                        
                        Text(settings.factoryTracks.contains(where: { $0.localizedCaseInsensitiveContains(audioManager.isPlaying ? audioManager.activeTrackTitle : settings.selectedTrack) }) ? "Studio Production Asset" : "Custom Cloud Asset")
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
        .onDisappear { vm.terminateEcosystemEngine() }
        .background(settings.canvasColor.backgroundColor(isDark: isDarkMode).ignoresSafeArea())
        
        .onChange(of: settings.numberOfWords) { oldValue, newValue in
            vm.refresh(using: settings)
        }
        
        .onChange(of: settings.freestyleMode) { oldValue, newValue in
            vm.refresh(using: settings)
        }
    }
    
    private var currentTrackIndex: Int {
        let currentTrackName = !audioManager.activeTrackTitle.isEmpty ? audioManager.activeTrackTitle : settings.selectedTrack
        let cleanCurrent = currentTrackName.replacingOccurrences(of: ".mp3", with: "").replacingOccurrences(of: ".m4a", with: "").lowercased()
        
        let index = settings.instrumentalBackingTracks.firstIndex(where: { track in
            let cleanTrack = track.replacingOccurrences(of: ".mp3", with: "").replacingOccurrences(of: ".m4a", with: "").lowercased()
            return cleanTrack == cleanCurrent
        })
        
        return index ?? 0
    }
    
    private func navigateTrack(forward: Bool) {
        let totalTracks = settings.instrumentalBackingTracks.count
        guard totalTracks > 0 else { return }
        
        let newIndex = forward ? (currentTrackIndex + 1) % totalTracks : (currentTrackIndex - 1 + totalTracks) % totalTracks
        
        if settings.instrumentalBackingTracks.indices.contains(newIndex) {
            let nextTrackName = settings.instrumentalBackingTracks[newIndex]
            settings.selectedTrack = nextTrackName
            
            if !settings.factoryTracks.contains(nextTrackName) && !LocalStorageManager.shared.isLocalFileReady(fileName: nextTrackName) {
                audioManager.stop()
                settings.downloadCloudTrackOnDemand(nextTrackName)
            } else if audioManager.isPlaying {
                audioManager.play(trackName: nextTrackName, using: settings)
            }
        }
    }
    
    private func formatTimeLabel(_ time: TimeInterval) -> String {
        guard !time.isNaN && !time.isInfinite && time > 0 else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
