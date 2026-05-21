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
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: "iCloud.freeflow")
            
            // Re-enabling explicit history tracking options to monitor background data merges across devices
            description.setOption(true as NSNumber, forKey: "NSPersistentStoreRemoteChangeNotificationOptionKey")
            description.setOption(true as NSNumber, forKey: "NSPersistentHistoryTrackingKey")
        } else {
            description.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved Core Data / CloudKit compilation fault: \(error), \(error.userInfo)")
            }
        })
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
