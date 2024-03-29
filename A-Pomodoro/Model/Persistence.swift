//
//  Persistence.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 21/12/2022.
//

import CoreData
import CloudKit
import SwiftUI

let gCloudKitContainerIdentifier = "iCloud.no.steinholm.A-Pomodoro"

/**
 This app doesn't necessarily post notifications from the main queue.
 */
extension Notification.Name {
    static let pomodoroStoreDidChange = Notification.Name("pomodoroStoreDidChange")
}

struct UserInfoKey {
    static let storeUUID = "storeUUID"
    static let transactions = "transactions"
}

struct TransactionAuthor {
    static let app = "app"
}

class PersistenceController: NSObject, ObservableObject {

    @Published var activeTaskId: NSManagedObjectID?

    var inMemory: Bool = false

    func getActiveTask(context: NSManagedObjectContext) -> Task? {
        if let activeTaskId = activeTaskId,
            let activeTask = context.object(with: activeTaskId) as? Task,
            activeTask.isMine
        {
            return activeTask
        }
        return nil
    }
    
    func getHistoryByObjectIdUrl(string: String?) -> History? {
        guard let string = string,
            let url = URL(string: string),
            let objectId = persistentContainer.persistentStoreCoordinator.managedObjectID(forURIRepresentation: url)
        else {
            return nil
        }
        return try? persistentContainer.viewContext.existingObject(with: objectId) as? History
    }

    static var active: PersistenceController {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return Self.preview
        }
        return Self.shared
    }

    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        var result = PersistenceController(inMemory: true)
        var viewContext = result.persistentContainer.viewContext
        
        let history = History(context: viewContext)
        
        let catWork = Category(context: viewContext)
        catWork.title = "Work"
        catWork.history = history
        let workTask0 = Task(context: viewContext)
        workTask0.category = catWork
        let workTask1 = Task(context: viewContext)
        workTask1.title = "This work task has a title"
        workTask1.category = catWork
        
        let catHobbyProgramming = Category(context: viewContext)
        catHobbyProgramming.title = "Hobby programming"
        catHobbyProgramming.history = history
        let hobbyTask0 = Task(context: viewContext)
        hobbyTask0.category = catHobbyProgramming
        let hobbyTask1 = Task(context: viewContext)
        hobbyTask1.title = "This hobby task has a title"
        hobbyTask1.category = catHobbyProgramming
        let hobbyTask2 = Task(context: viewContext)
        hobbyTask2.title = "Hobby task 2"
        hobbyTask2.category = catHobbyProgramming
        
        let tasks = [
            workTask0, workTask1, hobbyTask0, hobbyTask1, hobbyTask2
        ]
        
        for i in 0..<50 {
            let newItem = PomodoroEntry(context: viewContext)
            let ago: Double = TimeInterval.hour * 5 * (Double(i) - Double.random(min: 0, max: 4))
            newItem.startDate = Date() - ago
            newItem.timerType = "pomodoro"
            if Double.random < 0.75 {
                newItem.task = tasks.randomElement()
            }
        }
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()
    
    var persistentCloudKitContainer: NSPersistentCloudKitContainer? {
        return self.persistentContainer as? NSPersistentCloudKitContainer
    }

    lazy var persistentContainer: NSPersistentContainer = {
        /**
         Prepare the containing folder for the Core Data stores.
         A Core Data store has companion files, so it's a good practice to put a store under a folder.
         */
        let baseURL = NSPersistentContainer.defaultDirectoryURL()
        let storeFolderURL = baseURL.appendingPathComponent("CoreDataStores")
        let privateStoreFolderURL = storeFolderURL.appendingPathComponent("Private")
        let sharedStoreFolderURL = storeFolderURL.appendingPathComponent("Shared")

        let fileManager = FileManager.default
        for folderURL in [privateStoreFolderURL, sharedStoreFolderURL] where !fileManager.fileExists(atPath: folderURL.path) {
            do {
                try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                fatalError("#\(#function): Failed to create the store folder: \(error)")
            }
        }

        let container = inMemory
            ? NSPersistentContainer(name: "A-Pomodoro")
            : NSPersistentCloudKitContainer(name: "A-Pomodoro")
        
        /**
         Grab the default (first) store and associate it with the CloudKit private database.
         Set up the store description by:
         - Specifying a filename for the store.
         - Enabling history tracking and remote notifications.
         - Specifying the iCloud container and database scope.
        */
        guard let privateStoreDescription = container.persistentStoreDescriptions.first else {
            fatalError("#\(#function): Failed to retrieve a persistent store description.")
        }
        privateStoreDescription.url = inMemory
            ? URL(fileURLWithPath: "/dev/null")
            : privateStoreFolderURL.appendingPathComponent("private.sqlite")
        

        if (!inMemory) {
            privateStoreDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            privateStoreDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            
            let cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: gCloudKitContainerIdentifier)
            cloudKitContainerOptions.databaseScope = .private
            privateStoreDescription.cloudKitContainerOptions = cloudKitContainerOptions
                
            /**
             Similarly, add a second store and associate it with the CloudKit shared database.
             */
            guard let sharedStoreDescription = privateStoreDescription.copy() as? NSPersistentStoreDescription else {
                fatalError("#\(#function): Copying the private store description returned an unexpected value.")
            }
            sharedStoreDescription.url = inMemory
                ? URL(fileURLWithPath: "/dev/null")
                : sharedStoreFolderURL.appendingPathComponent("shared.sqlite")
    
            let sharedStoreOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: gCloudKitContainerIdentifier)
            sharedStoreOptions.databaseScope = .shared
            sharedStoreDescription.cloudKitContainerOptions = sharedStoreOptions

            container.persistentStoreDescriptions.append(sharedStoreDescription)
        }

        /**
         Load the persistent stores.
         */
        container.loadPersistentStores(completionHandler: { (loadedStoreDescription, error) in
            guard error == nil else {
                fatalError("#\(#function): Failed to load persistent stores:\(error!)")
            }
            guard let cloudKitContainerOptions = loadedStoreDescription.cloudKitContainerOptions else {
                return
            }
            if cloudKitContainerOptions.databaseScope == .private {
                self._privatePersistentStore = container.persistentStoreCoordinator.persistentStore(for: loadedStoreDescription.url!)
            } else if cloudKitContainerOptions.databaseScope  == .shared {
                self._sharedPersistentStore = container.persistentStoreCoordinator.persistentStore(for: loadedStoreDescription.url!)
            }
        })
        
        if (inMemory) {
            return container
        }

        /**
         Run initializeCloudKitSchema() once to update the CloudKit schema every time you change the Core Data model.
         Don't call this code in the production environment.
         */
        #if InitializeCloudKitSchema
        do {
            if let container = container as? NSPersistentCloudKitContainer {
                try container.initializeCloudKitSchema()
            }
        } catch {
            ALog(level: .error, " initializeCloudKitSchema: \(error)")
        }
        #else
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.transactionAuthor = TransactionAuthor.app

        /**
         Automatically merge the changes from other contexts.
         */
        container.viewContext.automaticallyMergesChangesFromParent = true

        /**
         Pin the viewContext to the current generation token and set it to keep itself up-to-date with local changes.
         */
        do {
            try container.viewContext.setQueryGenerationFrom(.current)
        } catch {
            fatalError("#\(#function): Failed to pin viewContext to the current generation:\(error)")
        }
        
        /**
         Observe the following notifications:
         - The remote change notifications from container.persistentStoreCoordinator.
         - The .NSManagedObjectContextDidSave notifications from any context.
         - The event change notifications from the container.
         */
        NotificationCenter.default.addObserver(self, selector: #selector(storeRemoteChange(_:)),
                                               name: .NSPersistentStoreRemoteChange,
                                               object: container.persistentStoreCoordinator)
        NotificationCenter.default.addObserver(self, selector: #selector(containerEventChanged(_:)),
                                               name: NSPersistentCloudKitContainer.eventChangedNotification,
                                               object: container)
        #endif
        return container
    }()

    init(inMemory: Bool = false) {
        self.inMemory = inMemory
    }
    
    private var _privatePersistentStore: NSPersistentStore?
    var privatePersistentStore: NSPersistentStore {
        return _privatePersistentStore!
    }

    private var _sharedPersistentStore: NSPersistentStore?
    var sharedPersistentStore: NSPersistentStore {
        return _sharedPersistentStore!
    }
    
    lazy var cloudKitContainer: CKContainer = {
        return CKContainer(identifier: gCloudKitContainerIdentifier)
    }()
        
    /**
     An operation queue for handling history-processing tasks: watching changes, deduplicating tags, and triggering UI updates, if needed.
     */
    lazy var historyQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
}


