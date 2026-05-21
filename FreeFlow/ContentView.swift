//
//  ContentView.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 21/05/2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var settings = FlowSettings()
    @State private var selectedTab: MainTab = .flow
    @State private var showingInspector: Bool = true
    
    // NATIVE STATE MANAGEMENT: Tracks whether the app is in the splash sequence or active use
    @State private var hasFinishedSplash: Bool = false

    var body: some View {
        Group {
            if hasFinishedSplash {
                // --- MAIN APP WORKSPACE LAYER ---
                MainTabView(selectedTab: $selectedTab, showingInspector: $showingInspector)
                    .environmentObject(settings)
                    .preferredColorScheme(settings.appTheme.colorScheme)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .onAppear {
                        // Evaluates the default 'true' value right at launch to keep the screen active
                        ScreenLockManager.shared.setScreenLockPrevention(enabled: settings.preventScreenLock)
                    }
            } else {
                // --- LIFECYCLE SPLASH ANIMATION LAYER ---
                SplashView()
                    .transition(.opacity)
                    .onAppear {
                        // Keeps the splash layout visible for a premium 2.5-second cinematic window
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                hasFinishedSplash = true
                            }
                        }
                    }
            }
        }
    }
}

#Preview {
    ContentView()
}
