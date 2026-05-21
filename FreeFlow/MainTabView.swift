//
//  MainTabView.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 21/05/2026.
//

import SwiftUI
import CoreData

// FIXED: Added an inspector state tracking enum to swap desktop side panels dynamically
enum DesktopSidebarContent {
    case inspector
    case mediaCenter
}

struct MainTabView: View {
    @Binding var selectedTab: MainTab
    @Binding var showingInspector: Bool
    
    // Mobile-only sheet toggle flags
    @State private var showingMediaCenterMobile = false
    @State private var showingMobileInspector = false
    
    // FIXED: Tracks which active panel should display in the macOS sidebar frame
    @State private var currentSidebarContent: DesktopSidebarContent = .inspector
    
    @EnvironmentObject private var settings: FlowSettings
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var backgroundColor: Color {
        colorScheme == .dark ? Color(white: 0.12) : Color(white: 0.95)
    }
    
    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        HStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                // FLOW TAB
                NavigationStack {
                    FlowView()
                        .navigationTitle(isCompact ? "FreeFlow" : "")
                        #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                        #endif
                        .toolbar {
                            ToolbarItemGroup(placement: .primaryAction) {
                                // STUDIO MEDIA CENTER TOGGLE
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
                                
                                // CONFIGURATION INSPECTOR TOGGLE
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

                // RHYMES TAB
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

                // EXPLORE TAB
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

                // NOTEPAD TAB
                NotepadView()
                    .tag(MainTab.notepad)
                    .tabItem {
                        Label("Notepad", systemImage: "note.text")
                    }
                    .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
            }
            .background(backgroundColor)
            
            // FIXED: DYNAMIC DESKTOP SIDEBAR CONTAINER (Only mounts on Regular viewports during Flow sessions)
            if showingInspector && !isCompact && selectedTab == .flow {
                Divider()
                    .opacity(colorScheme == .dark ? 0.1 : 0.3)
                
                VStack(spacing: 0) {
                    switch currentSidebarContent {
                    case .inspector:
                        FlowInspectorView()
                            .environmentObject(settings)
                            .id(settings.appTheme)
                    case .mediaCenter:
                        // FIXED: Renders the media center inside the permanent canvas on macOS
                        MediaCenterView()
                            .environmentObject(settings)
                            .id(settings.appTheme)
                    }
                }
                .frame(width: 320)
                .transition(.move(edge: .trailing))
            }
        }
        .background(backgroundColor.ignoresSafeArea())
        
        // --- MOBILE ONLY REGION ---
        // These sheets only activate on compact iOS environments, keeping macOS completely native
        #if os(iOS)
        .sheet(isPresented: $showingMediaCenterMobile) {
            NavigationStack {
                MediaCenterView()
            }
            .environmentObject(settings)
            .id(settings.appTheme)
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
            .id(settings.appTheme)
        }
        #endif
    }
}

#Preview {
    MainTabView(selectedTab: .constant(.flow), showingInspector: .constant(true))
        .environmentObject(FlowSettings())
}
