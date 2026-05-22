//
//  LocalStorageManager.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 22/05/2026.
//

import Foundation

struct LocalStorageManager {
    static let shared = LocalStorageManager()
    
    private init() {}
    
    private var documentsDirectory: URL {
        if let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") {
            if !FileManager.default.fileExists(atPath: iCloudURL.path) {
                try? FileManager.default.createDirectory(at: iCloudURL, withIntermediateDirectories: true)
            }
            return iCloudURL
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func copyAudioToSandbox(from sourceURL: URL) -> (title: String, fileName: String)? {
        let shouldRelease = sourceURL.startAccessingSecurityScopedResource()
        defer { if shouldRelease { sourceURL.stopAccessingSecurityScopedResource() } }
        
        let exactFileName = sourceURL.lastPathComponent
        let destinationURL = documentsDirectory.appendingPathComponent(exactFileName)
        let cleanTitle = sourceURL.deletingPathExtension().lastPathComponent
        
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            return (cleanTitle, exactFileName)
        }
        
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return (cleanTitle, exactFileName)
        } catch {
            print("📂 [LocalStorageManager] Copy failure: \(error.localizedDescription)")
            return nil
        }
    }
    
    func fileExistsInSandbox(fileName: String) -> Bool {
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        return isFilePresentAtURL(fileURL)
    }
    
    func resolveAbsoluteLocalURL(for filename: String) -> URL {
        return documentsDirectory.appendingPathComponent(filename)
    }
    
    /// Checks for standard files as well as hidden iCloud download placeholders (.filename.m4a.icloud)
    private func isFilePresentAtURL(_ url: URL) -> Bool {
        if FileManager.default.fileExists(atPath: url.path) { return true }
        
        let directory = url.deletingLastPathComponent()
        let hiddenCloudStubURL = directory.appendingPathComponent(".\(url.lastPathComponent).icloud")
        return FileManager.default.fileExists(atPath: hiddenCloudStubURL.path)
    }
    
    /// Verifies if a file exists locally with real byte contents, ignoring iCloud status delays
    func isLocalFileReady(fileName: String) -> Bool {
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let fileSize = attributes[.size] as? UInt64 {
                return fileSize > 0
            }
            return true
        }
        return false
    }
    
    /// Locates the real path and ensures un-downloaded cloud files are pulled down safely
    /// without blocking CoreAudio threads or causing main pipeline freezes.
    func resolveAudioURL(for trackName: String) -> URL? {
        let customURL = documentsDirectory.appendingPathComponent(trackName)
        
        if isFilePresentAtURL(customURL) {
            // Check if the file is completely local and fully downloaded
            if let values = try? customURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]),
               values.ubiquitousItemDownloadingStatus == .current && isLocalFileReady(fileName: trackName) {
                return customURL
            } else {
                // FIXED: Trigger the underlying system download daemon but instantly return the URL pointer footprint.
                // This lets your dedicated background worker task handle polling tracking safely.
                print("📂 [LocalStorageManager] Triggering background iCloud download for track path: \(trackName)")
                try? FileManager.default.startDownloadingUbiquitousItem(at: customURL)
                return customURL
            }
        }
        
        let needsExtension = !trackName.hasSuffix(".mp3") && !trackName.hasSuffix(".m4a")
        let formattedName = needsExtension ? "\(trackName).mp3" : trackName
        let localFallbackURL = documentsDirectory.appendingPathComponent(formattedName)
        
        if FileManager.default.fileExists(atPath: localFallbackURL.path) {
            return localFallbackURL
        }
        
        let cleanBundleName = trackName.replacingOccurrences(of: ".m4a", with: "").replacingOccurrences(of: ".mp3", with: "")
        return Bundle.main.url(forResource: cleanBundleName, withExtension: "mp3")
    }
    
    func deletePhysicalFile(fileName: String) {
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        if isFilePresentAtURL(fileURL) {
            let coordinator = NSFileCoordinator()
            var coordinationError: NSError?
            
            coordinator.coordinate(writingItemAt: fileURL, options: .init(rawValue: 0), error: &coordinationError) { url in
                do {
                    try FileManager.default.removeItem(at: url)
                } catch {
                    print("⚠️ [LocalStorageManager] Failed to remove asset: \(error.localizedDescription)")
                }
            }
        }
    }
}
