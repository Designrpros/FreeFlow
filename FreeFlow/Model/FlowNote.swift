//
//  FlowNote.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 21/05/2026.
//

import Foundation

struct FlowNote: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var content: String
    var lastModified: Date
}
