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
    @State private var hasFinishedSplash: Bool = false

    // FIXED: Uses the updated .colorScheme property mapped inside our clean AppTheme framework
    private var resolvedColorScheme: ColorScheme? {
        settings.appTheme.colorScheme
    }

    var body: some View {
        Group {
            if hasFinishedSplash {
                MainTabView(selectedTab: $selectedTab, showingInspector: $showingInspector)
                    .environmentObject(settings)
                    .preferredColorScheme(resolvedColorScheme)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .onAppear {
                        ScreenLockManager.shared.setScreenLockPrevention(enabled: settings.preventScreenLock)
                    }
            } else {
                SplashView()
                    .environmentObject(settings)
                    .transition(.opacity)
                    .onAppear {
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
