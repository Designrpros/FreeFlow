//
//  MainTabView.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 21/05/2026.
//

import SwiftUI
import CoreData

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
}
