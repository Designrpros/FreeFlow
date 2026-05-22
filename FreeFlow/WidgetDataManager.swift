//
//  WidgetDataManager.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 22/05/2026.
//

import Foundation
import WidgetKit // FIXED: Moved to file scope header block

struct WidgetWordData: Codable {
    let word: String
    let category: String
    let definition: String
    let rhymes: [String]
}

final class WidgetDataManager {
    static let shared = WidgetDataManager()
    
    // Configured precisely to connect into your custom shared storage entitlement lane
    private let appGroupSuiteName = "group.FreeFlow"
    
    func saveWordToWidgetContainer(word: String, category: String, definition: String, rhymes: [String]) {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupSuiteName) else { return }
        
        let payload = WidgetWordData(word: word, category: category, definition: definition, rhymes: rhymes)
        if let encoded = try? JSONEncoder().encode(payload) {
            sharedDefaults.set(encoded, forKey: "todays_anchor_payload")
            
            // FIXED: Removed the inline import. Calling WidgetCenter here is now perfectly valid.
            #if os(iOS) || os(macOS)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        }
    }
    
    func readWordFromSharedContainer() -> WidgetWordData {
        let fallback = WidgetWordData(
            word: "Ignite",
            category: "Action / Fire",
            definition: "To catch fire or cause to catch fire; arouse or inflame an emotion.",
            rhymes: ["Light", "Flight", "Bright", "Might"]
        )
        
        guard let sharedDefaults = UserDefaults(suiteName: appGroupSuiteName),
              let rawData = sharedDefaults.data(forKey: "todays_anchor_payload"),
              let decoded = try? JSONDecoder().decode(WidgetWordData.self, from: rawData) else {
            return fallback
        }
        return decoded
    }
}
