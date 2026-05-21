//
//  FlowInspectorView.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 21/05/2026.
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

    // NATIVE CORE DATA SOURCE: Monitors cloud changes to our user-uploaded audio track listings live
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
        settings.factoryTracks
    }

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
                                    .foregroundColor(settings.freestyleMode == mode ? .blue : secondaryTextColor.opacity(0.6))
                            }
                            .padding()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                settings.freestyleMode = mode
                            }
                            
                            if mode != FreestyleMode.allCases.last {
                                Divider().background(lineSeparatorColor)
                            }
                        }
                    }
                    .background(cardBackground)
                    .cornerRadius(8)
                }

                // UPDATED ACTIVE SECTION: FOCUS WORD MONITOR CONTROL
                if settings.freestyleMode == .wordFlowPlusRhymes {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Focus Word Control")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(secondaryTextColor)
                        
                        VStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Anchor Word Target")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(secondaryTextColor)
                                    Spacer()
                                    if !settings.customFocusWord.isEmpty {
                                        Button("Clear") {
                                            settings.customFocusWord = ""
                                        }
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.red.opacity(0.8))
                                    }
                                }
                                
                                // Interactive TextField directly modifying focus calculations
                                TextField("Type target word (e.g., Flame)...", text: $settings.customFocusWord)
                                    .textFieldStyle(.plain)
                                    .padding(10)
                                    .background(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white)
                                    .cornerRadius(6)
                                    .foregroundColor(mainTextColor)
                                    .font(.system(size: 13, design: .monospaced))
                                    .disableAutocorrection(true)
                                
                                Text("Leave field blank to let the engine pick a random anchor automatically on tap.")
                                    .font(.system(size: 10))
                                    .foregroundColor(secondaryTextColor.opacity(0.8))
                                    .padding(.top, 2)
                            }
                        }
                        .padding()
                        .background(cardBackground)
                        .cornerRadius(8)
                    }
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
                        
                        // FIXED: Uses rawValue matching to bypass SDK global namespace collision with .automatic entirely
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
                                    .foregroundColor(settings.wordSource == source ? .blue : secondaryTextColor.opacity(0.6))
                            }
                            .padding()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                settings.wordSource = source
                            }
                            
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
                            Button(action: {
                                withAnimation { showUploadedTracks.toggle() }
                            }) {
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
                            Button(action: {
                                withAnimation { showStudioAssets.toggle() }
                            }) {
                                HStack {
                                    Image(systemName: "music.note.list")
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
                    Button(action: {
                        withAnimation {
                            settings.showAdvanced.toggle()
                        }
                    }) {
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
                            
                            // UPDATED STRUCTURAL TOGGLE WITH EXPLICIT ICON AND ALIGNMENT SPACER
                            HStack(alignment: .center, spacing: 12) {
                                Image(systemName: "lock.slash")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.blue)
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
                                )) {
                                    Text("")
                                }
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                .labelsHidden()
                            }
                            .padding(.vertical, 2)
                        }
                        .padding([.horizontal, .bottom])
                        .background(cardBackground)
                    }
                }
                .cornerRadius(8)
            }
            .padding([.horizontal, .bottom])
        }
        .background(panelBackground)
    }
    
    // UPDATED VIEWBUILDER: Resolves titles and file tracking definitions through Core Data references
    @ViewBuilder
    private func inspectorTrackRow(title: String, identifier: String, isCustom: Bool) -> some View {
        let isSelected = settings.selectedTrack == identifier
        
        HStack {
            Image(systemName: isCustom ? "icloud.and.arrow.up" : "music.note")
                .font(.system(size: 12))
                .foregroundColor(isSelected ? .blue : secondaryTextColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
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
            }
            
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundColor(isSelected ? .blue : secondaryTextColor.opacity(0.6))
        }
        .padding()
        .contentShape(Rectangle())
        .onTapGesture {
            // Guard clause to protect playback systems from trying to load un-downloaded cloud nodes
            if isCustom && !LocalStorageManager.shared.fileExistsInSandbox(fileName: identifier) {
                return
            }
            settings.selectedTrack = identifier
            if audioManager.isPlaying {
                audioManager.play(trackName: identifier, using: settings)
            }
        }
    }
}
