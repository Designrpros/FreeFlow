//
//  MainTabView.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 21/05/2026.
//

import SwiftUI

struct MainTabView: View {
    @Binding var selectedTab: MainTab
    @Binding var showingInspector: Bool
    
    @State private var showingMediaCenter = false
    @State private var showingMobileInspector = false
    
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
        NavigationStack {
            HStack(spacing: 0) {
                TabView(selection: $selectedTab) {
                    FlowView()
                        .tag(MainTab.flow)
                        .tabItem {
                            Label("Flow", systemImage: "waveform")
                        }

                    RhymesView()
                        .tag(MainTab.rhymes)
                        .tabItem {
                            Label("Rhymes", systemImage: "textformat.abc")
                        }

                    ExploreView()
                        .tag(MainTab.explore)
                        .tabItem {
                            Label("Explore", systemImage: "safari")
                        }

                    NotepadView()
                        .tag(MainTab.notepad)
                        .tabItem {
                            Label("Notepad", systemImage: "note.text")
                        }
                }
                .background(backgroundColor)
                
                // SIDEBAR SIDE PANEL (Mac / iPad)
                if showingInspector && !isCompact {
                    Divider()
                        .opacity(colorScheme == .dark ? 0.1 : 0.3)
                    FlowInspectorView()
                        .environmentObject(settings)
                        .id(settings.appTheme)
                        .frame(width: 320)
                        .transition(.move(edge: .trailing))
                }
            }
            .background(backgroundColor.ignoresSafeArea())
            .navigationTitle(isCompact ? "FreeFlow" : "")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showingMediaCenter = true
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
                                showingInspector.toggle()
                            }
                        }
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16))
                    }
                    .help("Show Inspector")
                }
            }
            // MEDIA CENTER SHEET CONTAINER
            .sheet(isPresented: $showingMediaCenter) {
                NavigationStack {
                    MediaCenterView()
                }
                // Explicitly pass environment and identity directly to the modal runtime context
                .environmentObject(settings)
                .id(settings.appTheme)
                #if os(macOS)
                .frame(minWidth: 500, minHeight: 450)
                #endif
            }
            // MOBILE INSPECTOR MODAL SHEET (iOS)
            .sheet(isPresented: $showingMobileInspector) {
                NavigationStack {
                    FlowInspectorView()
                        .navigationTitle("Configure Flow")
                        #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                        #endif
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") {
                                    showingMobileInspector = false
                                }
                            }
                        }
                }
                // FIX: Explicitly pass environment and identity directly to the sheet context
                .environmentObject(settings)
                .id(settings.appTheme)
            }
        }
    }
}

#Preview {
    MainTabView(selectedTab: .constant(.flow), showingInspector: .constant(true))
        .environmentObject(FlowSettings())
}
