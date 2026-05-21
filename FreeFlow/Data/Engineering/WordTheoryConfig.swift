//
//  WordTheoryConfig.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 20/05/2026.
//

import Foundation

enum WordType: String, CaseIterable, Identifiable {
    case noun = "Noun"
    case verb = "Verb"
    case adjective = "Adjective"
    case adverb = "Adverb"
    
    var id: String { rawValue }
}

struct WordMetadata {
    let text: String
    let type: WordType
    let rhymes: [String]
}
