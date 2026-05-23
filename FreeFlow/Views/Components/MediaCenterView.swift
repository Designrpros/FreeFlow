//
//  MediaCenterView.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 22/05/2026.
//

import SwiftUI
import UniformTypeIdentifiers
import CoreData

struct MediaCenterView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var settings: FlowSettings
    @StateObject private var audioManager = AudioManager.shared
    @State private var showFilePicker = false
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \UploadedTrackEntity.dateAdded, ascending: true)],
        animation: .default
    )
    private var coreDataUploadedTracks: FetchedResults<UploadedTrackEntity>
    
    private var isDarkMode: Bool {
        if settings.appTheme == .system { return colorScheme == .dark }
        return settings.appTheme == .dark
    }
    
    private var panelBackground: Color {
        settings.canvasColor.backgroundColor(isDark: isDarkMode)
    }
    
    private var cardBackground: Color {
        isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.04)
    }
    
    private var mainTextColor: Color { isDarkMode ? .white : .black }
    private var secondaryTextColor: Color { isDarkMode ? .white.opacity(0.4) : .black.opacity(0.5) }
    private var lineSeparatorColor: Color { isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.06) }
    
    private var factoryTracks: [String] {
        settings.availableTracks.filter { settings.factoryTracks.contains($0) }
    }

    // 🚀 FIXED: Changed from 'some Scene' back to 'some View' to satisfy protocol inheritance constraints safely
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Configure app execution parameters, studio monitoring, and cloud audio layouts.")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(secondaryTextColor)
                    }
                    .padding(.top, 16)
                    
                    // --- ENGINE CONFIGURATIONS PANEL CARD ---
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Engine Configurations")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(secondaryTextColor)
                        
                        VStack(spacing: 14) {
                            // 1. MASTER VOLUME
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Label("Master Volume", systemImage: "speaker.wave.3.fill")
                                        .font(.system(size: 13, weight: .medium))
                                    Spacer()
                                    Text("\(Int(audioManager.masterVolume * 100))%")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(secondaryTextColor)
                                }
                                .foregroundColor(mainTextColor)
                                
                                Slider(value: $audioManager.masterVolume, in: 0...1)
                                    .tint(settings.appAccent.color)
                            }
                            
                            Divider().background(lineSeparatorColor)
                            
                            // 2. PLAYBACK SPEED (BPM WARP)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Label("Studio Speed / BPM Warp", systemImage: "metronome.fill")
                                        .font(.system(size: 13, weight: .medium))
                                    Spacer()
                                    Text(String(format: "%.2fx", settings.playbackSpeed))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(settings.playbackSpeed == 1.0 ? secondaryTextColor : settings.appAccent.color)
                                }
                                .foregroundColor(mainTextColor)
                                
                                Slider(value: $settings.playbackSpeed, in: 0.5...2.0, step: 0.05)
                                    .tint(settings.appAccent.color)
                            }
                            
                            Divider().background(lineSeparatorColor)
                            
                            // 3. PITCH SHIFTING (KEY TRANSPOSITION)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Label("Key Transposition (Pitch)", systemImage: "tuningfork")
                                        .font(.system(size: 13, weight: .medium))
                                    Spacer()
                                    Text(settings.pitchShiftSemitones == 0 ? "Original Key" : "\(settings.pitchShiftSemitones > 0 ? "+" : "")\(settings.pitchShiftSemitones) semitones")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(settings.pitchShiftSemitones == 0 ? secondaryTextColor : settings.appAccent.color)
                                }
                                .foregroundColor(mainTextColor)
                                
                                Slider(
                                    value: Binding(
                                        get: { Float(settings.pitchShiftSemitones) },
                                        set: { settings.pitchShiftSemitones = Int(round($0)) }
                                    ),
                                    in: -12...12,
                                    step: 1.0
                                )
                                .tint(settings.appAccent.color)
                                
                                HStack {
                                    Text("-12 st").font(.system(size: 9, design: .monospaced))
                                    Spacer()
                                    Text("0").font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundColor(settings.pitchShiftSemitones == 0 ? settings.appAccent.color : secondaryTextColor.opacity(0.5))
                                    Spacer()
                                    Text("+12 st").font(.system(size: 9, design: .monospaced))
                                }
                                .foregroundColor(secondaryTextColor.opacity(0.6))
                                .padding(.top, -2)
                            }
                            
                            Divider().background(lineSeparatorColor)
                            
                            // 4. CROSSFADE LOOP SETUP
                            VStack(spacing: 10) {
                                HStack(alignment: .center) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(settings.appAccent.color)
                                        .frame(width: 20, alignment: .leading)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Seamless Crossfade Loop")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(mainTextColor)
                                        Text("Blends track overlap seamlessly during cycle endpoints.")
                                            .font(.system(size: 10))
                                            .foregroundColor(secondaryTextColor)
                                    }
                                    Spacer()
                                    Toggle("", isOn: $settings.loopWithCrossfade)
                                        .toggleStyle(SwitchToggleStyle(tint: settings.appAccent.color))
                                        .labelsHidden()
                                }
                                
                                if settings.loopWithCrossfade {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("Crossfade Window Duration")
                                                .font(.system(size: 11, weight: .medium))
                                            Spacer()
                                            Text(String(format: "%.1fs", settings.crossfadeDuration))
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundColor(settings.appAccent.color)
                                        }
                                        Slider(value: $settings.crossfadeDuration, in: 0.1...5.0, step: 0.1)
                                            .tint(settings.appAccent.color)
                                    }
                                    .padding(.leading, 26)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                                }
                            }
                            .animation(.easeInOut(duration: 0.2), value: settings.loopWithCrossfade)
                            
                            Divider().background(lineSeparatorColor)
                            
                            // 5. TRACK ENDING BEHAVIOR
                            HStack {
                                Text("Track Ending Behavior")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(mainTextColor)
                                Spacer()
                                Picker("", selection: $settings.endBehavior) {
                                    ForEach(PlaybackEndBehavior.allCases) { behavior in
                                        Text(behavior.rawValue).tag(behavior)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                            }
                        }
                        .padding()
                        .background(cardBackground)
                        .cornerRadius(8)
                    }
                    
                    // --- USER UPLOADS CONTENT CARD ---
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center) {
                            Text("My Uploads")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(secondaryTextColor)
                            Spacer()
                            Button {
                                showFilePicker = true
                            } label: {
                                Label("Import MP3", systemImage: "plus.circle")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(settings.appAccent.color)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        VStack(spacing: 0) {
                            if coreDataUploadedTracks.isEmpty {
                                HStack {
                                    Image(systemName: "cloud.sun")
                                        .font(.system(size: 14))
                                        .foregroundColor(secondaryTextColor)
                                    Text("No custom tracks uploaded yet. Tap '+' to import.")
                                        .font(.system(size: 12))
                                        .italic()
                                        .foregroundColor(secondaryTextColor)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(cardBackground)
                                .cornerRadius(8)
                            } else {
                                ForEach(coreDataUploadedTracks) { track in
                                    trackRow(title: track.title ?? "Unknown Track", identifier: track.fileName ?? "", isCustom: true, entityRef: track)
                                    
                                    if track != coreDataUploadedTracks.last {
                                        Divider().background(lineSeparatorColor)
                                    }
                                }
                                .background(cardBackground)
                                .cornerRadius(8)
                            }
                        }
                    }
                    
                    // --- FACTORY ASSETS CARD ---
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Studio Assets")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(secondaryTextColor)
                        
                        VStack(spacing: 0) {
                            ForEach(factoryTracks, id: \.self) { track in
                                trackRow(title: track, identifier: track, isCustom: false, entityRef: nil)
                                
                                if track != factoryTracks.last {
                                    Divider().background(lineSeparatorColor)
                                }
                            }
                        }
                        .background(cardBackground)
                        .cornerRadius(8)
                    }
                }
                .padding([.horizontal, .bottom])
            }
        }
        .background(panelBackground.ignoresSafeArea())
        .navigationTitle("Media Center")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
            #endif
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.audio, UTType.mp3],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let selectedURL = urls.first else { return }
                if let fileInfo = LocalStorageManager.shared.copyAudioToSandbox(from: selectedURL) {
                    let alreadyRegistered = coreDataUploadedTracks.contains { $0.fileName == fileInfo.fileName }
                    
                    if !alreadyRegistered {
                        let newTrack = UploadedTrackEntity(context: viewContext)
                        newTrack.id = UUID()
                        newTrack.title = fileInfo.title
                        newTrack.fileName = fileInfo.fileName
                        newTrack.dateAdded = Date()
                        
                        try? viewContext.save()
                    }
                    
                    settings.selectedTrack = fileInfo.fileName
                    if audioManager.isPlaying {
                        audioManager.play(trackName: fileInfo.fileName, using: settings)
                    }
                }
            case .failure(let error):
                print("File import failed: \(error.localizedDescription)")
            }
        }
    }
    
    @ViewBuilder
    private func trackRow(title: String, identifier: String, isCustom: Bool, entityRef: UploadedTrackEntity?) -> some View {
        let isSelected = settings.selectedTrack == identifier
        
        let strippedName = identifier.replacingOccurrences(of: ".mp3", with: "").replacingOccurrences(of: ".m4a", with: "")
        let isLocalReady = !isCustom ||
                           LocalStorageManager.shared.isLocalFileReady(fileName: identifier) ||
                           LocalStorageManager.shared.isLocalFileReady(fileName: strippedName)
                           
        let currentDownloadState = settings.trackDownloadStates[identifier] ?? .idle
        
        HStack {
            Image(systemName: isCustom ? "icloud.and.arrow.up" : "music.note")
                .font(.system(size: 13))
                .foregroundColor(isSelected ? settings.appAccent.color : secondaryTextColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundColor(mainTextColor)
                
                if !isLocalReady {
                    Group {
                        switch currentDownloadState {
                        case .downloading:
                            Text("Downloading track from iCloud... • PROCESSING")
                                .foregroundColor(settings.appAccent.color)
                        default:
                            Text("Available in your iCloud library • TAP TO DOWNLOAD")
                                .foregroundColor(.orange.opacity(0.8))
                        }
                    }
                    .font(.system(size: 10, design: .rounded))
                }
            }
            
            Spacer()
            
            if audioManager.isPlaying && audioManager.activeTrackTitle == identifier {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 11))
                    .foregroundColor(settings.appAccent.color)
                    .padding(.trailing, 4)
            }
            
            Group {
                if !isLocalReady {
                    switch currentDownloadState {
                    case .downloading:
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 16, height: 16)
                    default:
                        Image(systemName: "icloud.and.arrow.down")
                            .font(.system(size: 14))
                            .foregroundColor(.orange.opacity(0.7))
                    }
                } else {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 15))
                        .foregroundColor(isSelected ? settings.appAccent.color : secondaryTextColor.opacity(0.4))
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .contextMenu {
            if isCustom, let entity = entityRef {
                Button(role: .destructive) {
                    deleteTrackAction(entity: entity, fileName: identifier)
                } label: {
                    Label("Delete Asset Permanently", systemImage: "trash")
                }
            } else {
                Text("System Asset • Locked")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onTapGesture {
            if !isLocalReady {
                settings.downloadCloudTrackOnDemand(identifier)
                return
            }
            
            settings.selectedTrack = identifier
            if audioManager.isPlaying {
                audioManager.play(trackName: identifier, using: settings)
            }
        }
    }
    
    private func deleteTrackAction(entity: UploadedTrackEntity, fileName: String) {
        if settings.selectedTrack == fileName {
            audioManager.stop()
            settings.selectedTrack = "Chrome_On_The_Curb.mp3"
        }
        settings.trackDownloadStates[fileName] = nil
        LocalStorageManager.shared.deletePhysicalFile(fileName: fileName)
        viewContext.delete(entity)
        try? viewContext.save()
    }
}
