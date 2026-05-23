//
//  RecordingsView.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 22/05/2026.
//

import SwiftUI
import AVFoundation

struct RecordingsView: View {
    enum FileProcessingState {
        case idle
        case downloading
        case ready(URL)
    }

    @EnvironmentObject private var settings: FlowSettings
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var audioManager = AudioManager.shared
    
    @State private var fileStates: [String: FileProcessingState] = [:]
    @State private var showingRenameAlert = false
    @State private var trackToRename: String? = nil
    @State private var newTrackName = ""
    
    private var isDarkMode: Bool {
        if settings.appTheme == .system { return colorScheme == .dark }
        return settings.appTheme == .dark
    }
    
    private var workspaceBackground: Color { settings.canvasColor.backgroundColor(isDark: isDarkMode) }
    private var mainTextColor: Color { isDarkMode ? .white : .black }
    private var cardBackground: Color { isDarkMode ? Color.white.opacity(0.04) : Color.black.opacity(0.03) }
    
    // Dynamic chronological resource sort maps latest file modifications to the top of the array stack
    private var recordedSessions: [String] {
        let files = settings.availableTracks.filter { $0.hasSuffix(".m4a") }
        
        return files.sorted { (file1, file2) -> Bool in
            let url1 = LocalStorageManager.shared.resolveAbsoluteLocalURL(for: file1)
            let url2 = LocalStorageManager.shared.resolveAbsoluteLocalURL(for: file2)
            
            let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
            let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
            
            // Latest date bubble on top
            return date1 > date2
        }
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
                                    
                                    Group {
                                        switch fileStates[filename] ?? .idle {
                                        case .downloading:
                                            Text("Downloading from iCloud Studio... • SYNCHRONIZING")
                                                .foregroundColor(settings.appAccent.color)
                                        case .ready:
                                            Text("Studio Session Asset • READY TO EXPORT")
                                                .foregroundColor(settings.appAccent.color.opacity(0.7))
                                        case .idle:
                                            Text("Studio Session Asset • AVAILABLE IN CLOUD")
                                                .foregroundColor(mainTextColor.opacity(0.4))
                                        }
                                    }
                                    .font(.system(size: 10, design: .monospaced))
                                }
                                
                                Spacer()
                                
                                // 🚀 FIXED: Double curly brackets removed completely
                                HStack(spacing: 16) {
                                    switch fileStates[filename] ?? .idle {
                                    case .downloading:
                                        ProgressView()
                                            .controlSize(.small)
                                            .frame(width: 20, height: 20)
                                            
                                    case .ready(let fileURL):
                                        ShareLink(item: fileURL) {
                                            Image(systemName: "square.and.arrow.up")
                                                .font(.system(size: 15))
                                                .foregroundColor(settings.appAccent.color)
                                        }
                                        .buttonStyle(.plain)
                                        
                                    case .idle:
                                        Button {
                                            evaluateAndPrepareFile(filename: filename, playImmediately: false)
                                        } label: {
                                            Image(systemName: "icloud.and.arrow.down")
                                                .font(.system(size: 15))
                                                .foregroundColor(secondaryTextColor)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    
                                    Button {
                                        handlePlaybackTap(for: filename)
                                    } label: {
                                        Image(systemName: isCurrentTrackPlaying(filename) ? "stop.circle.fill" : "play.circle.fill")
                                            .font(.system(size: 22))
                                            .foregroundColor(settings.appAccent.color)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                            .contextMenu {
                                Button {
                                    handlePlaybackTap(for: filename)
                                } label: {
                                    Label(isCurrentTrackPlaying(filename) ? "Stop Playback" : "Play Session",
                                          systemImage: isCurrentTrackPlaying(filename) ? "stop.fill" : "play.fill")
                                }
                                
                                Button {
                                    initiateRename(for: filename)
                                } label: {
                                    Label("Rename Session", systemImage: "pencil")
                                }
                                
                                if case .ready(let fileURL) = fileStates[filename] ?? .idle {
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
                            .onAppear {
                                checkInitialFileState(filename: filename)
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
    
    private func checkInitialFileState(filename: String) {
        if LocalStorageManager.shared.isLocalFileReady(fileName: filename) {
            let targetURL = LocalStorageManager.shared.resolveAbsoluteLocalURL(for: filename)
            fileStates[filename] = .ready(targetURL)
            return
        }
        
        let targetURL = LocalStorageManager.shared.resolveAbsoluteLocalURL(for: filename)
        if let values = try? targetURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]),
           values.ubiquitousItemDownloadingStatus == .current {
            fileStates[filename] = .ready(targetURL)
        } else {
            fileStates[filename] = .idle
        }
    }
    
    private func handlePlaybackTap(for filename: String) {
        if isCurrentTrackPlaying(filename) {
            audioManager.stop()
            return
        }
        
        if case .ready = fileStates[filename] {
            audioManager.play(trackName: filename, using: settings)
        } else {
            evaluateAndPrepareFile(filename: filename, playImmediately: true)
        }
    }
    
    private func evaluateAndPrepareFile(filename: String, playImmediately: Bool) {
        fileStates[filename] = .downloading
        
        DispatchQueue.global(qos: .userInitiated).async {
            let targetURL = LocalStorageManager.shared.resolveAbsoluteLocalURL(for: filename)
            try? FileManager.default.startDownloadingUbiquitousItem(at: targetURL)
            
            var downloadComplete = false
            var attempts = 0
            let maxAttempts = 120
            
            while !downloadComplete && attempts < maxAttempts {
                if LocalStorageManager.shared.isLocalFileReady(fileName: filename) {
                    downloadComplete = true
                } else if let values = try? targetURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]),
                          values.ubiquitousItemDownloadingStatus == .current {
                    downloadComplete = true
                } else {
                    attempts += 1
                    Thread.sleep(forTimeInterval: 0.5)
                }
            }
            
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if downloadComplete {
                        self.fileStates[filename] = .ready(targetURL)
                        if playImmediately {
                            self.audioManager.play(trackName: filename, using: self.settings)
                        }
                    } else {
                        if FileManager.default.fileExists(atPath: targetURL.path) {
                            self.fileStates[filename] = .ready(targetURL)
                            if playImmediately {
                                self.audioManager.play(trackName: filename, using: self.settings)
                            }
                        } else {
                            self.fileStates[filename] = .idle
                        }
                    }
                }
            }
        }
    }
    
    private var secondaryTextColor: Color { isDarkMode ? .white.opacity(0.4) : .black.opacity(0.5) }
    private func cleanDisplayName(for filename: String) -> String { filename.replacingOccurrences(of: "FreeFlow_Session_", with: "").replacingOccurrences(of: ".m4a", with: "") }
    private func isCurrentTrackPlaying(_ filename: String) -> Bool { audioManager.isPlaying && audioManager.activeTrackTitle == filename }
    
    private func initiateRename(for filename: String) {
        trackToRename = filename
        newTrackName = cleanDisplayName(for: filename)
        showingRenameAlert = true
    }
    
    private func executeRename(oldFilename: String, newDisplayName: String) {
        let cleanedInput = newDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedInput.isEmpty else { return }
        
        let originalURL = LocalStorageManager.shared.resolveAbsoluteLocalURL(for: oldFilename)
        let targetFilename = "FreeFlow_Session_\(cleanedInput).m4a"
        let destinationURL = LocalStorageManager.shared.resolveAbsoluteLocalURL(for: targetFilename)
        
        guard originalURL != destinationURL else { return }
        if isCurrentTrackPlaying(oldFilename) { audioManager.stop() }
        
        do {
            try FileManager.default.moveItem(at: originalURL, to: destinationURL)
            let oldState = fileStates[oldFilename]
            fileStates[oldFilename] = nil
            if case .ready = oldState {
                fileStates[targetFilename] = .ready(destinationURL)
            } else {
                checkInitialFileState(filename: targetFilename)
            }
            
            if settings.selectedTrack == oldFilename { settings.selectedTrack = targetFilename }
            settings.refreshTracksRoster()
        } catch {
            print("⚠️ [RecordingsView] Physical disk move file transaction failed: \(error.localizedDescription)")
        }
        
        trackToRename = nil
        newTrackName = ""
    }
    
    private func deleteRecording(filename: String) {
        if isCurrentTrackPlaying(filename) { audioManager.stop() }
        fileStates[filename] = nil
        LocalStorageManager.shared.deletePhysicalFile(fileName: filename)
        settings.refreshTracksRoster()
    }
}
