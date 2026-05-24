//
//  FreeFlowTests.swift
//  FreeFlowTests
//
//  Created by Vegar Berentsen on 24/05/2026.
//

import Testing
import Foundation
@testable import FreeFlow

@Suite("Ecosystem Settings & Logic Validation", .serialized)
struct FreeFlowTests {
    
    @Test("Verify that track names are sanitized accurately to standard extensions via roster refresh")
    func testTrackExtensionSanitization() {
        let settings = FlowSettings()
        
        // 1. Test shorthand factory name mapping
        settings.selectedTrack = "jazzyflow"
        settings.refreshTracksRoster()
        #expect(settings.selectedTrack == "JazzyFlow.mp3")
        
        settings.selectedTrack = "late_august"
        settings.refreshTracksRoster()
        #expect(settings.selectedTrack == "Late_August_Porch.mp3")
        
        // 2. Test custom track string formatting. To prevent the production fallback from
        // resetting it to "Chrome_On_The_Curb.mp3", we temporarily simulate the file on disk.
        let targetDirectory: URL
        if let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") {
            targetDirectory = iCloudURL
        } else {
            targetDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        }
        
        let customTrackName = "My_Custom_Freestyle_Beat.mp3"
        let fileURL = targetDirectory.appendingPathComponent(customTrackName)
        
        // Write an empty dummy file to pass the refreshTracksRoster disk verification check
        try? Data().write(to: fileURL)
        
        settings.selectedTrack = "My_Custom_Freestyle_Beat"
        settings.refreshTracksRoster()
        
        // Clean up the dummy file immediately to keep the sandbox pristine
        try? FileManager.default.removeItem(at: fileURL)
        
        // Assert it matches successfully now that it passed the disk verification gate
        #expect(settings.selectedTrack == "My_Custom_Freestyle_Beat.mp3")
    }
    
    @Test("Ensure value clamps safeguard layout parameters from overflow")
    func testValueClampingBoundaries() {
        let settings = FlowSettings()
        
        settings.numberOfWords = 10
        #expect(settings.numberOfWords == 6)
        
        settings.numberOfWords = -5
        #expect(settings.numberOfWords == 1)
        
        settings.playbackSpeed = 5.0
        #expect(settings.playbackSpeed == 2.0)
        
        settings.playbackSpeed = 0.1
        #expect(settings.playbackSpeed == 0.5)
    }
    
    @Test("Verify that session recordings are filtered out of the background tracks roster")
    func testTrackRosterFiltering() {
        let settings = FlowSettings()
        
        settings.availableTracks = [
            "Chrome_On_The_Curb.mp3",
            "FreeFlow_Session_2026_05_24.m4a",
            "JazzyFlow.mp3"
        ]
        
        let filteredBackingTracks = settings.instrumentalBackingTracks
        
        #expect(filteredBackingTracks.count == 2)
        #expect(filteredBackingTracks.contains("Chrome_On_The_Curb.mp3"))
        #expect(!filteredBackingTracks.contains("FreeFlow_Session_2026_05_24.m4a"))
    }
}

// MARK: - Mock Repository for ViewModel State Testing

struct MockWordsRepository: WordsRepository {
    func initialWords(count: Int) -> [String] {
        return Array(["Flow", "Rhyme", "Studio", "Vibe", "Beat", "Mic"].prefix(count))
    }

    func randomWords(count: Int) -> [String] {
        return Array(["Flow", "Rhyme", "Studio", "Vibe", "Beat", "Mic"].prefix(count))
    }
    
    func rhymeWords(count: Int, focusingOn focusWord: String?, useRhymeMode: Bool) async -> [String] {
        return Array(["Flow", "Rhyme", "Studio", "Vibe", "Beat", "Mic"].prefix(count))
    }
}

@Suite("ViewModel State Machines", .serialized)
struct ViewModelTests {
    
    @MainActor
    @Test("Verify data loading lifecycle maps correctly when performing an explicit refresh pass")
    func testViewModelFetchLifecycle() async {
        let mockRepo = MockWordsRepository()
        let vm = FlowViewModel(repo: mockRepo)
        let settings = FlowSettings()
        
        settings.freestyleMode = .standardKeywords
        settings.wordSource = .staticLibrary
        settings.numberOfWords = 3
        
        vm.refresh(using: settings)
        
        #expect(vm.words.count == 3)
        #expect(vm.isLoading == false)
    }
}

// MARK: - Audio Recording State Verification

@Suite("Audio Recording State Verification", .serialized)
struct AudioRecorderTests {
    
    @MainActor
    @Test("Verify that stopRecording safely preserves state and early exits if no active session exists")
    func testDefensiveStopRecordingBypass() {
        let settings = FlowSettings()
        let recorderManager = AudioRecorderManager.shared
        
        settings.isRecordingSession = true
        settings.recordingDuration = 45.0
        
        recorderManager.stopRecording(settings: settings)
        
        #expect(settings.isRecordingSession == true)
        #expect(settings.recordingDuration == 45.0)
    }
    
    @Test("Verify initial layout structures for recording properties inside FlowSettings")
    func testInitialRecordingSettingsState() {
        let settings = FlowSettings()
        
        #expect(settings.isRecordingSession == false)
        #expect(settings.recordingDuration == 0.0)
    }
}

// MARK: - Algorithmic Core Engine Validation

@Suite("Rhymes Engine Database Validation", .serialized)
struct RhymesEngineTests {
    
    @Test("Verify direct lookup for primary keywords returns their mapped rhyme buckets")
    func testDirectRhymeLookup() {
        // "ghost" is a primary entry key inside NounVocabulary source array
        let rhymes = RhymesDatabase.getRhymes(for: "ghost")
        
        #expect(!rhymes.isEmpty)
        // Ensure the bucket correctly returns corresponding rhyme family elements
        #expect(rhymes.contains("coast") || rhymes.contains("host") || rhymes.contains("post"))
    }
    
    @Test("Verify reverse lookup for words residing inside a master rhyme array bucket")
    func testReverseRhymeLookup() {
        // "coast" is not a primary key, but lives inside the "ghost" rhyme bucket
        let rhymes = RhymesDatabase.getRhymes(for: "coast")
        
        #expect(!rhymes.isEmpty)
        // Ensure the reverse-lookup engine successfully traces it back to the master family
        #expect(rhymes.contains("ghost") || rhymes.contains("host") || rhymes.contains("toast"))
    }
    
    @Test("Verify unmapped fallback words gracefully return the generic rhymes matrix")
    func testUnmappedWordFallback() {
        // Test a nonsense word that doesn't exist anywhere in your vocabulary files
        let rhymes = RhymesDatabase.getRhymes(for: "completely_unmapped_freestyle_slang_123")
        
        #expect(rhymes.count == RhymesDatabase.genericRhymes.count)
        #expect(rhymes.contains("flow"))
    }
}

@Suite("Repository Algorithmic Matrix Validation", .serialized)
struct RepositoryLogicTests {
    
    @Test("Verify randomWords generation enforces correct counting boundaries and variations")
    func testRandomWordsGeneration() {
        let repo = StaticWordsRepository()
        
        // Ensure requesting 0 words returns an empty structure safely
        let zeroWords = repo.randomWords(count: 0)
        #expect(zeroWords.isEmpty)
        
        // Ensure requesting a specific index generates exactly that count
        let requestedCount = 4
        let words = repo.randomWords(count: requestedCount)
        #expect(words.count == requestedCount)
        
        // Assert all strings are lowercase and sanitized cleanly
        for word in words {
            #expect(!word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            #expect(word == word.lowercased())
        }
    }
}
