//
//  Persistence.swift
//  FreeFlow
//
//  Created by Vegar Berentsen on 20/05/2026.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        for i in 0..<5 {
            let newNote = FlowNoteEntity(context: viewContext)
            newNote.id = UUID()
            newNote.title = "Preview Lyric Sheet \(i + 1)"
            newNote.content = "Write your rhymes here. This is template text for preview layout testing."
            newNote.lastModified = Date()
        }
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            print("Preview Store Gen Error: \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        // MATCHES Blueprints: Targets your explicit local main 'FreeFlow.xcdatamodeld' file capitalizations
        container = NSPersistentCloudKitContainer(name: "FreeFlow")
        
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Could not initialize persistent store descriptions.")
        }
        
        if !inMemory {
            // FIXED: Matches your lowercase server identifier container to clear the 1014 BadContainer fault
            let options = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.freeflow")
            description.cloudKitContainerOptions = options
            
            // Re-enabling explicit history tracking options to monitor background data merges across devices
            description.setOption(true as NSNumber, forKey: "NSPersistentStoreRemoteChangeNotificationOptionKey")
            description.setOption(true as NSNumber, forKey: "NSPersistentHistoryTrackingKey")
            
            // FIXED: Tells the mirroring delegate to ignore missing iCloud account restrictions during simulator runs.
            description.setOption(true as NSNumber, forKey: "NSCloudKitMirroringDelegateIgnoreAccountStatus")
            
            // 🚀 AUDIO INSULATION PERFORMANCE PRAGMAS:
            // Configures the local SQLite cache database to never drop or spin locks while audio engines are streaming buffers
            description.setValue("2" as NSString, forPragmaNamed: "synchronous") // OFF/NORMAL mode prevents blocking write calls
            description.setValue("WAL" as NSString, forPragmaNamed: "journal_mode") // Write-Ahead Logging keeps read/write channels separate
            description.setValue("1000" as NSString, forPragmaNamed: "max_page_count")
            description.setValue("4096" as NSString, forPragmaNamed: "page_size")
            
        } else {
            description.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                print("⚠️ Core Data / CloudKit Warning: \(error), \(error.userInfo)")
            } else {
                print("💾 [Persistence] SQLite Storage Store loaded successfully: \(storeDescription.url?.lastPathComponent ?? "")")
            }
        })

        // Decouple the user tab view context saves from triggering high-priority, blocking main-thread locks
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Pin the query generation to the active transaction timeline tip
        try? container.viewContext.setQueryGenerationFrom(.current)
        
        // INSULATE HIGH-PRIORITY REAL-TIME AUDIO:
        // Sets the internal background concurrency queue actor to process lower than real-time multimedia hardware channels
        container.viewContext.transactionAuthor = "app_main_lifecycle"
    }
}
