//
//  MediaCenterView.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 21/05/2026.
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
    
    private var panelBackground: Color {
        colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.95)
    }
    
    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.04)
    }
    
    private var mainTextColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.4) : .black.opacity(0.5)
    }
    
    private var lineSeparatorColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.06)
    }
    
    private var factoryTracks: [String] {
        settings.availableTracks.filter { settings.factoryTracks.contains($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // SUB-TITLE DESCRIPTION HERO BLOCK
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Configure engine parameters and manage custom local file sets")
                            .font(.system(size: 11))
                            .foregroundColor(secondaryTextColor)
                    }
                    .padding(.top, 16)
                    
                    // CONFIGURATIONS PANEL CARD
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Engine Configurations")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(secondaryTextColor)
                        
                        VStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Label("Master Volume", systemImage: "speaker.wave.3.fill")
                                        .font(.system(size: 13, weight: .medium))
                                    Spacer()
                                    Text("\(Int(audioManager.masterVolume * 100))%")
                                        .font(.system(size: 11))
                                        .foregroundColor(secondaryTextColor)
                                }
                                .foregroundColor(mainTextColor)
                                
                                Slider(value: $audioManager.masterVolume, in: 0...1)
                                    .tint(.blue)
                            }
                            
                            Divider().background(lineSeparatorColor)
                            
                            HStack(alignment: .center, spacing: 12) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.blue)
                                    .frame(width: 20, alignment: .leading)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Seamless Crossfade Loop")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(mainTextColor)
                                    Text("Fades overlapping track endings over a clean 1-second window.")
                                        .font(.system(size: 10))
                                        .foregroundColor(secondaryTextColor)
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: Binding(
                                    get: { settings.loopWithCrossfade },
                                    set: { settings.loopWithCrossfade = $0 }
                                ))
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                .labelsHidden()
                            }
                            .padding(.vertical, 2)
                            
                            Divider().background(lineSeparatorColor)
                            
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
                    
                    // SECTION 1: MY UPLOADS CARD
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
                                    .foregroundColor(.blue)
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
                    
                    // SECTION 2: STUDIO ASSETS CARD
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
        
        // FIXED: Replaced old hardcoded titles with a modern native inline title configuration
        .navigationTitle("Media Center")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
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
                        
                        do {
                            try viewContext.save()
                        } catch {
                            print("Core Data tracking record save failure: \(error.localizedDescription)")
                        }
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
        
        HStack {
            Image(systemName: isCustom ? "icloud.and.arrow.up" : "music.note")
                .font(.system(size: 13))
                .foregroundColor(isSelected ? .blue : secondaryTextColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundColor(mainTextColor)
                
                if isCustom && !LocalStorageManager.shared.fileExistsInSandbox(fileName: identifier) {
                    Text("Waiting for iCloud download...")
                        .font(.system(size: 10))
                        .foregroundColor(.orange.opacity(0.8))
                }
            }
            
            Spacer()
            
            if audioManager.isPlaying && audioManager.activeTrackTitle == identifier {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.blue)
                    .padding(.trailing, 4)
            }
            
            if isCustom, let entity = entityRef {
                Button {
                    deleteTrackAction(entity: entity, fileName: identifier)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }
            
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 15))
                .foregroundColor(isSelected ? .blue : secondaryTextColor.opacity(0.4))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            if isCustom && !LocalStorageManager.shared.fileExistsInSandbox(fileName: identifier) {
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
            settings.selectedTrack = "Chrome_On_The_Curb"
        }
        LocalStorageManager.shared.deletePhysicalFile(fileName: fileName)
        viewContext.delete(entity)
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to delete CoreData custom track record: \(error.localizedDescription)")
        }
    }
}
