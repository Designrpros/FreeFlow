//
//  ThemeColors.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 20/05/2026.
//

import SwiftUI

extension Color {
    // Dynamically adapts based on system Light / Dark mode appearance
    static let appBackground = Color("AppBackground")
    static let inspectorBackground = Color("InspectorBackground")
    static let elementBackground = Color("ElementBackground")
}

// A simple preview helper to inspect the palette
struct ThemeColors_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("App Canvas Accent")
                .padding()
                .background(Color("AppBackground"))
            Text("Sidebar Inspector Surface")
                .padding()
                .background(Color("InspectorBackground"))
            Text("Interactive Controls Block")
                .padding()
                .background(Color("ElementBackground"))
        }
        .padding()
    }
}
