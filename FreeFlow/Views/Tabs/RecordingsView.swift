//
//  RecordingsView.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 21/05/2026.
//

import SwiftUI
import AVFoundation

struct RecordingsView: View {
    @EnvironmentObject private var settings: FlowSettings
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var audioManager = AudioManager.shared
    
    // Rename interaction states
    @State private var showingRenameAlert = false
    @State private var trackToRename: String? = nil
    @State private var newTrackName = ""
    
    private var isDarkMode: Bool {
        if settings.appTheme == .system {
            return colorScheme == .dark
        }
        return settings.appTheme == .dark
    }
    
    private var workspaceBackground: Color {
        settings.canvasColor.backgroundColor(isDark: isDarkMode)
    }
    
    private var mainTextColor: Color {
        isDarkMode ? .white : .black
    }
    
    private var cardBackground: Color {
        isDarkMode ? Color.white.opacity(0.04) : Color.black.opacity(0.03)
    }
    
    // Isolate recorded studio sessions (.m4a files)
    private var recordedSessions: [String] {
        settings.availableTracks.filter { $0.hasSuffix(".m4a") }
    }

    var body: some View {
        VStack(spacing: 0) {
            if recordedSessions.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "mic.slash")
                        .font(.system(size: 32))
                        .foregroundColor(mainTextColor.opacity(0.2))
                    Text("No recorded sessions found.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                    Text("Tap the microphone icon in the toolbar on the 'Flow' tab to record your first performance.")
                        .font(.system(size: 12))
                        .foregroundColor(mainTextColor.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Spacer()
                }
            } else {
                List {
                    Section {
                        ForEach(recordedSessions, id: \.self) { filename in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(cleanDisplayName(for: filename))
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundColor(mainTextColor)
                                    Text("Studio Session Asset • M4A")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(mainTextColor.opacity(0.4))
                                }
                                
                                Spacer()
                                
                                HStack(spacing: 16) {
                                    // Native Cross-Platform Share/Download Link Engine
                                    if let fileURL = resolveRecordingURL(for: filename) {
                                        ShareLink(item: fileURL) {
                                            Image(systemName: "square.and.arrow.down")
                                                .font(.system(size: 16))
                                                .foregroundColor(settings.appAccent.color.opacity(0.8))
                                        }
                                        .buttonStyle(.plain)
                                        .help("Export/Download recording asset out of sandbox storage")
                                    }
                                    
                                    // Audio Playback Control
                                    Button {
                                        togglePlayback(for: filename)
                                    } label: {
                                        Image(systemName: isCurrentTrackPlaying(filename) ? "stop.circle.fill" : "play.circle.fill")
                                            .font(.system(size: 22))
                                            .foregroundColor(settings.appAccent.color)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                            // --- NEW: Context Menu Support (Long Press / Right Click) ---
                            .contextMenu {
                                Button {
                                    togglePlayback(for: filename)
                                } label: {
                                    Label(isCurrentTrackPlaying(filename) ? "Stop Playback" : "Play Session",
                                          systemImage: isCurrentTrackPlaying(filename) ? "stop.fill" : "play.fill")
                                }
                                
                                Button {
                                    initiateRename(for: filename)
                                } label: {
                                    Label("Rename Session", systemImage: "pencil")
                                }
                                
                                if let fileURL = resolveRecordingURL(for: filename) {
                                    ShareLink(item: fileURL) {
                                        Label("Export / Share", systemImage: "square.and.arrow.up")
                                    }
                                }
                                
                                Divider()
                                
                                Button(role: .destructive) {
                                    deleteRecording(filename: filename)
                                } label: {
                                    Label("Delete Permanently", systemImage: "trash")
                                }
                            }
                            // --- Existing Swipe Gestures ---
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteRecording(filename: filename)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    initiateRename(for: filename)
                                } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                        }
                    } header: {
                        Text("Captured Studio Sessions (\(recordedSessions.count))")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .listRowBackground(cardBackground)
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
        }
        .background(workspaceBackground.ignoresSafeArea())
        .onAppear {
            settings.refreshTracksRoster()
        }
        // Unified Modal Overlay handling secure transactional string modifications
        .alert("Rename Session Sheet", isPresented: $showingRenameAlert, presenting: trackToRename) { filename in
            TextField("Enter session description...", text: $newTrackName)
                #if os(iOS)
                .textInputAutocapitalization(.words)
                #endif
            Button("Cancel", role: .cancel) {
                trackToRename = nil
                newTrackName = ""
            }
            Button("Save Changes") {
                executeRename(oldFilename: filename, newDisplayName: newTrackName)
            }
        } message: { filename in
            Text("Provide a clean studio identifier title for your saved performance take.")
        }
    }
    
    // --- HELPER UTILITIES ---
    
    private func cleanDisplayName(for filename: String) -> String {
        filename
            .replacingOccurrences(of: "FreeFlow_Session_", with: "")
            .replacingOccurrences(of: ".m4a", with: "")
    }
    
    private func isCurrentTrackPlaying(_ filename: String) -> Bool {
        audioManager.isPlaying && audioManager.activeTrackTitle == filename
    }
    
    private func togglePlayback(for filename: String) {
        if isCurrentTrackPlaying(filename) {
            audioManager.stop()
        } else {
            audioManager.play(trackName: filename, using: settings)
        }
    }
    
    private func resolveRecordingURL(for filename: String) -> URL? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }
    
    // --- STORAGE OPERATION RUNLOOPS ---
    
    private func initiateRename(for filename: String) {
        trackToRename = filename
        newTrackName = cleanDisplayName(for: filename)
        showingRenameAlert = true
    }
    
    private func executeRename(oldFilename: String, newDisplayName: String) {
        let cleanedInput = newDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedInput.isEmpty else { return }
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let originalURL = documentsDirectory.appendingPathComponent(oldFilename)
        
        let targetFilename = "FreeFlow_Session_\(cleanedInput).m4a"
        let destinationURL = documentsDirectory.appendingPathComponent(targetFilename)
        
        guard originalURL != destinationURL else { return }
        
        if isCurrentTrackPlaying(oldFilename) {
            audioManager.stop()
        }
        
        do {
            try FileManager.default.moveItem(at: originalURL, to: destinationURL)
            
            if settings.selectedTrack == oldFilename {
                settings.selectedTrack = targetFilename
            }
            
            settings.refreshTracksRoster()
        } catch {
            print("Physical disk move file transaction failed: \(error.localizedDescription)")
        }
        
        trackToRename = nil
        newTrackName = ""
    }
    
    private func deleteRecording(filename: String) {
        if isCurrentTrackPlaying(filename) {
            audioManager.stop()
        }
        LocalStorageManager.shared.deletePhysicalFile(fileName: filename)
        settings.refreshTracksRoster()
    }
}
