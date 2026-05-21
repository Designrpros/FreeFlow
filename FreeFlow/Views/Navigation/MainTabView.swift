//
//  MainTabView.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 21/05/2026.
//

import SwiftUI
import CoreData
import AVFoundation

enum DesktopSidebarContent {
    case inspector
    case mediaCenter
}

struct MainTabView: View {
    @MainActor @Binding var selectedTab: MainTab
    @MainActor @Binding var showingInspector: Bool
    
    @State private var showingMediaCenterMobile = false
    @State private var showingMobileInspector = false
    @State private var currentSidebarContent: DesktopSidebarContent = .inspector
    
    @EnvironmentObject private var settings: FlowSettings
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    private var isDarkMode: Bool {
        if settings.appTheme == .system {
            return colorScheme == .dark
        }
        return settings.appTheme == .dark
    }

    var body: some View {
        HStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    FlowView()
                        .navigationTitle(isCompact ? "FreeFlow" : "")
                        #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                        #endif
                        .toolbar {
                            ToolbarItemGroup(placement: .primaryAction) {
                                
                                // NEW: Studio Session Mic Recording Button
                                Button {
                                    if settings.isRecordingSession {
                                        AudioRecorderManager.shared.stopRecording(settings: settings)
                                    } else {
                                        #if os(iOS)
                                        // Dynamic cross-platform fallback for iOS target authorization hooks
                                        AVAudioSession.sharedInstance().requestRecordPermission { granted in
                                            if granted {
                                                DispatchQueue.main.async {
                                                    AudioRecorderManager.shared.startRecording(settings: settings)
                                                }
                                            }
                                        }
                                        #else
                                        // macOS permissions are natively evaluated at runtime via Sandbox Capability switches
                                        AudioRecorderManager.shared.startRecording(settings: settings)
                                        #endif
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        if settings.isRecordingSession {
                                            // Blinking red status node displaying active session timeline tracking
                                            Circle()
                                                .fill(Color.red)
                                                .frame(width: 8, height: 8)
                                            Text(formatDuration(settings.recordingDuration))
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundColor(.red)
                                        }
                                        
                                        Image(systemName: settings.isRecordingSession ? "mic.fill" : "mic")
                                            .font(.system(size: 16))
                                            .foregroundColor(settings.isRecordingSession ? .red : settings.appAccent.color)
                                    }
                                }
                                .help(settings.isRecordingSession ? "Stop Session Recording" : "Record Studio Session")
                                
                                // --- Existing Control Structure Elements ---
                                Button {
                                    if isCompact {
                                        showingMediaCenterMobile = true
                                    } else {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if showingInspector && currentSidebarContent == .mediaCenter {
                                                showingInspector = false
                                            } else {
                                                currentSidebarContent = .mediaCenter
                                                showingInspector = true
                                            }
                                        }
                                    }
                                } label: {
                                    Image(systemName: "music.note.house")
                                        .font(.system(size: 16))
                                }
                                .help("Open Studio Media Center")
                                
                                Button {
                                    if isCompact {
                                        showingMobileInspector = true
                                    } else {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if showingInspector && currentSidebarContent == .inspector {
                                                showingInspector = false
                                            } else {
                                                currentSidebarContent = .inspector
                                                showingInspector = true
                                            }
                                        }
                                    }
                                } label: {
                                    Image(systemName: "gearshape")
                                        .font(.system(size: 16))
                                }
                                .help("Show Inspector")
                            }
                        }
                }
                .tag(MainTab.flow)
                .tabItem {
                    Label("Flow", systemImage: "waveform")
                }

                NavigationStack {
                    RhymesView()
                        .navigationTitle("Rhymes")
                        #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                        #endif
                }
                .tag(MainTab.rhymes)
                .tabItem {
                    Label("Rhymes", systemImage: "textformat.abc")
                }

                NavigationStack {
                    ExploreView()
                        .navigationTitle("Explore")
                        #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                        #endif
                }
                .tag(MainTab.explore)
                .tabItem {
                    Label("Explore", systemImage: "safari")
                }
                
                NotepadView()
                    .tag(MainTab.notepad)
                    .tabItem {
                        Label("Notepad", systemImage: "note.text")
                    }
                    .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)

                NavigationStack {
                    RecordingsView()
                        .navigationTitle("Recordings")
                        #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                        #endif
                }
                .tag(MainTab.recordings)
                .tabItem {
                    Label("Recordings", systemImage: "waveform.badge.mic")
                }
            }
            .background(Color.clear)
            
            if showingInspector && !isCompact && selectedTab == .flow {
                Divider()
                    .opacity(isDarkMode ? 0.1 : 0.3)
                
                VStack(spacing: 0) {
                    switch currentSidebarContent {
                    case .inspector:
                        FlowInspectorView()
                            .environmentObject(settings)
                            // FIXED: Removed the disruptive .id(...) token wrapper entirely
                            // to preserve internal scroll positions during layout changes
                    case .mediaCenter:
                        MediaCenterView()
                            .environmentObject(settings)
                            // FIXED: Removed the disruptive .id(...) token wrapper here too
                    }
                }
                .frame(width: 320)
                .transition(.move(edge: .trailing))
            }
        }
        .background(settings.canvasColor.backgroundColor(isDark: isDarkMode).ignoresSafeArea())
        
        #if os(iOS)
        .sheet(isPresented: $showingMediaCenterMobile) {
            NavigationStack {
                MediaCenterView()
            }
            .environmentObject(settings)
            .id(settings.canvasColor.rawValue + settings.appTheme.rawValue + settings.appAccent.rawValue)
        }
        .sheet(isPresented: $showingMobileInspector) {
            NavigationStack {
                FlowInspectorView()
                    .navigationTitle("Configure Flow")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showingMobileInspector = false
                            }
                        }
                    }
            }
            .environmentObject(settings)
            .id(settings.canvasColor.rawValue + settings.appTheme.rawValue + settings.appAccent.rawValue)
        }
        #endif
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
