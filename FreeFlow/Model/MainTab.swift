//
//  MainTab.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 20/05/2026.
//

import Foundation

enum MainTab: String, CaseIterable, Identifiable {
    case flow = "Flow"
    case rhymes = "Rhymes"
    case explore = "Explore"
    case notepad = "Notepad"
    
    var id: String { rawValue }
}
