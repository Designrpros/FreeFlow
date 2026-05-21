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

    var body: some View {
        MainTabView(selectedTab: $selectedTab, showingInspector: $showingInspector)
            .environmentObject(settings)
            // Fixed: Removed the hard override environment color scheme line that was blocking theme updates
            .preferredColorScheme(settings.appTheme.colorScheme)
            .onAppear {
                // Evaluates the default 'true' value right at launch to keep the screen active
                ScreenLockManager.shared.setScreenLockPrevention(enabled: settings.preventScreenLock)
            }
    }
}

#Preview {
    ContentView()
}
