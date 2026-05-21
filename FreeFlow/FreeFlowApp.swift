//
//  FreeFlowApp.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 20/05/2026.
//

import SwiftUI

@main
struct FreeFlowApp: App {
    @StateObject private var settings = FlowSettings()
    
    // NATIVE CORE DATA STACK: Instantiates your shared persistent cloud container instance
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                // FIXED: Injects the managed context straight down the environment hierarchy
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                // Injects your settings object so ContentView and all subviews can read it
                .environmentObject(settings)
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        #endif
    }
}
