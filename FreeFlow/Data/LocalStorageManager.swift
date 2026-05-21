//
//  LocalStorageManager.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 21/05/2026.
//

import Foundation

struct LocalStorageManager {
    static let shared = LocalStorageManager()
    
    private init() {}
    
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    /// Copies an external file into the local sandbox directory and returns the clean file details
    func copyAudioToSandbox(from sourceURL: URL) -> (title: String, fileName: String)? {
        let shouldRelease = sourceURL.startAccessingSecurityScopedResource()
        defer { if shouldRelease { sourceURL.stopAccessingSecurityScopedResource() } }
        
        let exactFileName = sourceURL.lastPathComponent
        let destinationURL = documentsDirectory.appendingPathComponent(exactFileName)
        let cleanTitle = sourceURL.deletingPathExtension().lastPathComponent
        
        // If file already exists, we return the names immediately without duplicate copies
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            return (cleanTitle, exactFileName)
        }
        
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return (cleanTitle, exactFileName)
        } catch {
            print("Physical disk copy failure: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Checks if a specific file name exists physically inside this device's storage
    func fileExistsInSandbox(fileName: String) -> Bool {
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    /// Locates the real file path for either a factory asset or a custom documents folder file
    func resolveAudioURL(for trackName: String) -> URL? {
        // 1. First check if it's an uploaded file matching a complete fileName extension pattern
        let customURL = documentsDirectory.appendingPathComponent(trackName)
        if FileManager.default.fileExists(atPath: customURL.path) {
            return customURL
        }
        
        // 2. Fallback check if it was stored without extension string details
        let localFallbackURL = documentsDirectory.appendingPathComponent("\(trackName).mp3")
        if FileManager.default.fileExists(atPath: localFallbackURL.path) {
            return localFallbackURL
        }
        
        // 3. Fall back to factory resources bundled in the main app build compile
        return Bundle.main.url(forResource: trackName, withExtension: "mp3")
    }
    
    /// Removes a custom file from the disk storage sandbox container
    func deletePhysicalFile(fileName: String) {
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                print("Failed to delete physical custom audio file: \(error.localizedDescription)")
            }
        }
    }
}
