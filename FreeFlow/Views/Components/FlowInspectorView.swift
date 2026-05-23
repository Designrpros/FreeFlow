//
//  FlowInspectorView.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 22/05/2026.
//

import SwiftUI
import CoreData

struct FlowInspectorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var settings: FlowSettings
    @StateObject private var audioManager = AudioManager.shared
    @Environment(\.colorScheme) private var colorScheme

    @State private var showUploadedTracks: Bool = true
    @State private var showStudioAssets: Bool = true

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \UploadedTrackEntity.dateAdded, ascending: true)],
        animation: .default
    )
    private var coreDataUploadedTracks: FetchedResults<UploadedTrackEntity>

    private var isDarkMode: Bool {
        if settings.appTheme == .system { return colorScheme == .dark }
        return settings.appTheme == .dark
    }

    private var panelBackground: Color { settings.canvasColor.backgroundColor(isDark: isDarkMode) }
    private var cardBackground: Color { isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.04) }
    private var mainTextColor: Color { isDarkMode ? .white : .black }
    private var secondaryTextColor: Color { isDarkMode ? .white.opacity(0.4) : .black.opacity(0.5) }
    private var lineSeparatorColor: Color { isDarkMode ? Color.white.opacity(0.05) : Color.black.opacity(0.06) }
    private var factoryTracks: [String] { settings.factoryTracks }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // SECTION: FREESTYLE MODES
                VStack(alignment: .leading, spacing: 8) {
                    Text("Freestyle Mode")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(secondaryTextColor)
                    
                    VStack(spacing: 0) {
                        ForEach(FreestyleMode.allCases) { mode in
                            HStack {
                                Text(mode.rawValue)
                                    .foregroundColor(mainTextColor)
                                Spacer()
                                Image(systemName: settings.freestyleMode == mode ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(settings.freestyleMode == mode ? settings.appAccent.color : secondaryTextColor.opacity(0.6))
                            }
                            .padding()
                            .contentShape(Rectangle())
                            .onTapGesture { settings.freestyleMode = mode }
                            
                            if mode != FreestyleMode.allCases.last {
                                Divider().background(lineSeparatorColor)
                            }
                        }
                    }
                    .background(cardBackground)
                    .cornerRadius(8)
                }

                // SMART FOCUS WORD MONITOR CONTROL
                if settings.freestyleMode == .wordFlowPlusRhymes {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Focus Word Control")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(secondaryTextColor)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Label("Manual Anchor Word", systemImage: "pin.circle.fill")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(mainTextColor)
                                Spacer()
                                Toggle("", isOn: $settings.useManualAnchor)
                                    .toggleStyle(SwitchToggleStyle(tint: settings.appAccent.color))
                                    .labelsHidden()
                                    .onChange(of: settings.useManualAnchor) { oldValue, newValue in
                                        if !newValue { settings.customFocusWord = "" }
                                    }
                            }
                            
                            if settings.useManualAnchor {
                                Divider().background(lineSeparatorColor)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("Anchor Word Target")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(secondaryTextColor)
                                        Spacer()
                                        if !settings.customFocusWord.isEmpty {
                                            Button("Clear") { settings.customFocusWord = "" }
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.red.opacity(0.8))
                                                .buttonStyle(.plain)
                                        }
                                    }
                                    
                                    TextField("Type target word (e.g., Flame)...", text: $settings.customFocusWord)
                                        .textFieldStyle(.plain)
                                        .padding(10)
                                        .background(isDarkMode ? Color.black.opacity(0.2) : Color.white)
                                        .cornerRadius(6)
                                        .foregroundColor(mainTextColor)
                                        .font(.system(size: 13, design: .monospaced))
                                        .disableAutocorrection(true)
                                    
                                    Text("The engine will stick to this word until modified or cleared.")
                                        .font(.system(size: 10))
                                        .foregroundColor(secondaryTextColor.opacity(0.8))
                                        .padding(.top, 2)
                                }
                                .transition(.asymmetric(insertion: .push(from: .top).combined(with: .opacity), removal: .opacity))
                            } else {
                                Divider().background(lineSeparatorColor)
                                
                                HStack(spacing: 6) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 12))
                                        .foregroundColor(settings.appAccent.color)
                                    Text("Engine is automatically generating random anchors on tap.")
                                        .font(.system(size: 11))
                                        .foregroundColor(secondaryTextColor)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 2)
                            }
                        }
                        .padding()
                        .background(cardBackground)
                        .cornerRadius(8)
                    }
                    .animation(.easeInOut(duration: 0.2), value: settings.useManualAnchor)
                }

                // SECTION 1: WORD GENERATION OPTIONS
                VStack(alignment: .leading, spacing: 8) {
                    Text("Word Generation")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(secondaryTextColor)
                    
                    VStack(spacing: 12) {
                        HStack {
                            Text("Number of Words:")
                                .foregroundColor(mainTextColor)
                            Spacer()
                            Stepper("\(settings.numberOfWords)", value: $settings.numberOfWords, in: 1...6)
                                .foregroundColor(mainTextColor)
                        }
                        
                        Divider().background(lineSeparatorColor)
                        
                        HStack {
                            Text("Refresh Style")
                                .foregroundColor(mainTextColor)
                            Spacer()
                            Picker("", selection: $settings.refreshStyle) {
                                ForEach(RefreshStyle.allCases) { style in
                                    Text(style.rawValue).tag(style)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }
                        
                        if settings.refreshStyle.rawValue == "Automatic" {
                            Divider().background(lineSeparatorColor)
                            
                            HStack {
                                Text("Change Words Every:")
                                    .foregroundColor(mainTextColor)
                                Spacer()
                                Picker("", selection: $settings.refreshInterval) {
                                    Text("10 sec").tag(10.0)
                                    Text("20 sec").tag(20.0)
                                    Text("30 sec").tag(30.0)
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                            }
                            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                        }
                    }
                    .padding()
                    .background(cardBackground)
                    .cornerRadius(8)
                }

                // SECTION 2: WORD PIPELINE SOURCES
                VStack(alignment: .leading, spacing: 8) {
                    Text("Word Source")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(secondaryTextColor)
                    
                    VStack(spacing: 0) {
                        ForEach(WordSource.allCases) { source in
                            HStack {
                                Text(source.rawValue)
                                    .foregroundColor(mainTextColor)
                                Spacer()
                                Image(systemName: settings.wordSource == source ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(settings.wordSource == source ? settings.appAccent.color : secondaryTextColor.opacity(0.6))
                            }
                            .padding()
                            .contentShape(Rectangle())
                            .onTapGesture { settings.wordSource = source }
                            
                            if source != WordSource.allCases.last {
                                Divider().background(lineSeparatorColor)
                            }
                        }
                    }
                    .background(cardBackground)
                    .cornerRadius(8)
                }

                // MUSIC TRACK CONTAINER STACK
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("User Content")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(secondaryTextColor)
                        
                        VStack(spacing: 0) {
                            Button(action: { withAnimation { showUploadedTracks.toggle() } }) {
                                HStack {
                                    Image(systemName: "icloud.and.arrow.up")
                                    Text("My Uploaded Tracks")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .rotationEffect(.degrees(showUploadedTracks ? 90 : 0))
                                }
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(mainTextColor)
                                .padding()
                                .background(cardBackground)
                            }
                            .buttonStyle(.plain)
                            
                            if showUploadedTracks {
                                VStack(spacing: 0) {
                                    if coreDataUploadedTracks.isEmpty {
                                        Divider().background(lineSeparatorColor)
                                        Text("No custom uploads.")
                                            .font(.system(size: 12))
                                            .italic()
                                            .foregroundColor(secondaryTextColor)
                                            .padding()
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    } else {
                                        ForEach(coreDataUploadedTracks) { track in
                                            Divider().background(lineSeparatorColor)
                                            inspectorTrackRow(
                                                title: track.title ?? "Unknown Track",
                                                identifier: track.fileName ?? "",
                                                isCustom: true
                                            )
                                        }
                                    }
                                }
                                .background(cardBackground)
                            }
                        }
                        .cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Studio Tracks")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(secondaryTextColor)
                        
                        VStack(spacing: 0) {
                            Button(action: { withAnimation { showStudioAssets.toggle() } }) {
                                HStack {
                                    Image(systemName: "music.note.house")
                                    Text("Studio Assets")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .rotationEffect(.degrees(showStudioAssets ? 90 : 0))
                                }
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(mainTextColor)
                                .padding()
                                .background(cardBackground)
                            }
                            .buttonStyle(.plain)
                            
                            if showStudioAssets {
                                VStack(spacing: 0) {
                                    ForEach(factoryTracks, id: \.self) { track in
                                        Divider().background(lineSeparatorColor)
                                        inspectorTrackRow(
                                            title: track,
                                            identifier: track,
                                            isCustom: false
                                        )
                                    }
                                }
                                .background(cardBackground)
                            }
                        }
                        .cornerRadius(8)
                    }
                }

                // SECTION 4: ADVANCED SETTINGS
                VStack(spacing: 0) {
                    Button(action: { withAnimation { settings.showAdvanced.toggle() } }) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("Advanced Settings")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .rotationEffect(.degrees(settings.showAdvanced ? 90 : 0))
                        }
                        .foregroundColor(mainTextColor)
                        .padding()
                        .background(cardBackground)
                    }
                    .buttonStyle(.plain)
                    
                    if settings.showAdvanced {
                        VStack(alignment: .leading, spacing: 12) {
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
                            
                            Divider().background(lineSeparatorColor)
                            
                            HStack {
                                Text("Appearance Theme")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(mainTextColor)
                                Spacer()
                                Picker("", selection: $settings.appTheme) {
                                    ForEach(AppTheme.allCases) { theme in
                                        Text(theme.rawValue).tag(theme)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                            }
                            
                            Divider().background(lineSeparatorColor)
                            
                            HStack {
                                Text("Canvas Color")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(mainTextColor)
                                Spacer()
                                Picker("", selection: $settings.canvasColor) {
                                    ForEach(CanvasColor.allCases) { canvas in
                                        Text(canvas.rawValue).tag(canvas)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                            }
                            
                            Divider().background(lineSeparatorColor)
                            
                            HStack {
                                Text("Accent Theme")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(mainTextColor)
                                Spacer()
                                Picker("", selection: $settings.appAccent) {
                                    ForEach(AppAccent.allCases) { accent in
                                        Text(accent.rawValue).tag(accent)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                            }
                            
                            Divider().background(lineSeparatorColor)
                            
                            HStack(alignment: .center, spacing: 12) {
                                Image(systemName: "lock.slash")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(settings.appAccent.color)
                                    .frame(width: 20, alignment: .leading)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Prevent Screen Lock")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(mainTextColor)
                                }
                                
                                Spacer()
                                
                                Toggle(isOn: Binding(
                                    get: { settings.preventScreenLock },
                                    set: { newValue in
                                        settings.preventScreenLock = newValue
                                        ScreenLockManager.shared.setScreenLockPrevention(enabled: newValue)
                                    }
                                )) { Text("") }
                                .toggleStyle(SwitchToggleStyle(tint: settings.appAccent.color))
                                .labelsHidden()
                            }
                            .padding(.vertical, 2)
                        }
                        .padding([.horizontal, .bottom])
                        .background(cardBackground)
                    }
                }
                .cornerRadius(8)
                
                // --- SECTION: ABOUT FREEFLOW STUDIO & CREDITS ---
                VStack(alignment: .leading, spacing: 8) {
                    Text("About Studio")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(secondaryTextColor)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "waveform.and.mic")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(settings.appAccent.color)
                            
                            Text("FreeFlow Studio")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(mainTextColor)
                            
                            Spacer()
                            
                            Text("v1.0")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(secondaryTextColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(mainTextColor.opacity(0.05))
                                .cornerRadius(4)
                        }
                        
                        Text("FreeFlow was crafted as a seamless tactical environment for fluid lyric engineering, streaming syllables, and capturing high-fidelity workspace takes without workflow interruption.")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(mainTextColor.opacity(0.7))
                            .lineSpacing(3)
                        
                        Divider().background(lineSeparatorColor)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("STUDIO PRODUCTION CREDIT")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(secondaryTextColor)
                            
                            HStack(spacing: 6) {
                                Image(systemName: "music.mic")
                                    .font(.system(size: 11))
                                    .foregroundColor(settings.appAccent.color)
                                Text("Instrumental studio assets produced by **Endrey at Studio 51**.")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundColor(mainTextColor.opacity(0.8))
                            }
                        }
                        .padding(.vertical, 2)
                        
                        Divider().background(lineSeparatorColor)
                        
                        Link(destination: URL(string: "https://buymeacoffee.com/Alcatelz")!) {
                            HStack {
                                Image(systemName: "cup.and.saucer.fill")
                                    .font(.system(size: 12))
                                Text("Buy Me a Coffee")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                Spacer()
                                Image(systemName: "arrow.up.forward")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.orange, Color.orange.opacity(0.85)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .background(cardBackground)
                    .cornerRadius(8)
                }
                
            }
            .padding([.horizontal, .bottom])
        }
        .background(panelBackground)
    }
    
    @ViewBuilder
    private func inspectorTrackRow(title: String, identifier: String, isCustom: Bool) -> some View {
        let isSelected = settings.selectedTrack == identifier
        
        // FIXED: Verifies local file mapping status cleanly across extensions via our updated LocalStorageManager method
        let strippedName = identifier.replacingOccurrences(of: ".mp3", with: "").replacingOccurrences(of: ".m4a", with: "")
        let isLocalReady = !isCustom ||
                           LocalStorageManager.shared.isLocalFileReady(fileName: identifier) ||
                           LocalStorageManager.shared.isLocalFileReady(fileName: strippedName)
                           
        let currentDownloadState = settings.trackDownloadStates[identifier] ?? .idle
        
        HStack {
            Group {
                if !isLocalReady && currentDownloadState == .downloading {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: isCustom ? "icloud.and.arrow.up" : "music.note")
                        .font(.system(size: 12))
                        .foregroundColor(isSelected ? settings.appAccent.color : secondaryTextColor)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(mainTextColor)
                
                if !isLocalReady {
                    Text(currentDownloadState == .downloading ? "Downloading track..." : "Tap to download from iCloud")
                        .font(.system(size: 10))
                        .foregroundColor(.orange.opacity(0.8))
                }
            }
            
            Spacer()
            
            if audioManager.isPlaying && audioManager.activeTrackTitle == identifier {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 11))
                    .foregroundColor(settings.appAccent.color)
            }
            
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundColor(isSelected ? settings.appAccent.color : secondaryTextColor.opacity(0.6))
        }
        .padding()
        .contentShape(Rectangle())
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
}
