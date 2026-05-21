//
//  DatamuseWord.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 21/05/2026.
//

// Clean codable structural entity representing the server response mapping
struct DatamuseWord: Codable, Identifiable, Hashable {
    var id: String { word }
    let word: String
    let score: Int?
    let numSyllables: Int?
}
