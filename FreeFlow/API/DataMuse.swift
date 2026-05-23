//
//  DatamuseAPI.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 21/05/2026.
//

import Foundation

enum ExploreType {
    case synonyms
    case associations
}

class DatamuseAPI {
    static let shared = DatamuseAPI()
    private init() {}
    
    /// Fetches clean phonetic rhyming streams using your query assembly pattern
    func fetchRhymes(for word: String) async -> [DatamuseWord] {
        let cleanWord = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanWord.isEmpty else { return [] }
        
        var components = URLComponents(string: "https://api.datamuse.com/words")
        components?.queryItems = [
            URLQueryItem(name: "rel_rhy", value: cleanWord),
            URLQueryItem(name: "md", value: "s"), // Requests syllable metadata info
            URLQueryItem(name: "max", value: "40")
        ]
        
        guard let url = components?.url else { return [] }
        var downloadedData: Data? = nil
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            downloadedData = data
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return []
            }
            
            let decoded = try JSONDecoder().decode([DatamuseWord].self, from: data)
            
            // Clean out matching anchors and sort by confidence scores
            return decoded
                .filter { $0.word.lowercased() != cleanWord }
                .sorted(by: { ($0.score ?? 0) > ($1.score ?? 0) })
                
        } catch {
            if let safeData = downloadedData, let rawString = String(data: safeData, encoding: .utf8) {
                print("Raw server rhyme response payload: \(rawString)")
            }
            print("Network error fetching rhymes from Datamuse: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Fetches semantic concept meanings or thematic triggers dynamically
    func fetchRelatedWords(phrase: String, type: ExploreType) async -> [DatamuseWord] {
        let cleanPhrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanPhrase.isEmpty else { return [] }
        
        var components = URLComponents(string: "https://api.datamuse.com/words")
        
        // ml = Means Like (Synonyms/Concepts), rel_trg = Triggers (Associated words)
        let parameterName = (type == .synonyms) ? "ml" : "rel_trg"
        
        components?.queryItems = [
            URLQueryItem(name: parameterName, value: cleanPhrase),
            URLQueryItem(name: "md", value: "s"),
            URLQueryItem(name: "max", value: "40")
        ]
        
        guard let url = components?.url else { return [] }
        var downloadedData: Data? = nil
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            downloadedData = data
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return []
            }
            
            let decoded = try JSONDecoder().decode([DatamuseWord].self, from: data)
            
            // 🚀 FIXED: Filter out the input anchor word and sort context entries cleanly by priority score metadata
            return decoded
                .filter { $0.word.lowercased() != cleanPhrase }
                .sorted(by: { ($0.score ?? 0) > ($1.score ?? 0) })
                
        } catch {
            if let safeData = downloadedData, let rawString = String(data: safeData, encoding: .utf8) {
                print("Raw server explore response payload: \(rawString)")
            }
            print("Network error exploring words from Datamuse: \(error.localizedDescription)")
            return []
        }
    }
}
