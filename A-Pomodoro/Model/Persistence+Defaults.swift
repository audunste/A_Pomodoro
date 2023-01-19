//
//  Persistence+Defaults.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 15/01/2023.
//

import Foundation

import CoreData
import CloudKit

extension PersistenceController {

    func makeSureDefaultsExist() {
        let container = persistentCloudKitContainer
        let taskContext = container.newTaskContext()
        taskContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        taskContext.performAndWait {
            do {
                let request = Task.fetchRequest()
                let count = try taskContext.count(for: request)
                if count > 0 {
                    let tasks = try request.execute()
                    for task in tasks {
                        if task.category == nil {
                            task.category = try self.getOrCreateDefaultCategory(taskContext)
                        }
                    }
                    ALog("history count: \(try taskContext.count(for: History.fetchRequest()))")
                    ALog("category count: \(try taskContext.count(for: Category.fetchRequest()))")
                    ALog("task count: \(try taskContext.count(for: Task.fetchRequest()))")
                    ALog("pomodoro count: \(try taskContext.count(for: PomodoroEntry.fetchRequest()))")
                    return
                }
                let activeTask = try self.doAddTask(context: taskContext)
                try taskContext.save()
                self.activeTaskId = activeTask.objectID
                ALog("created default task with category: \(String(describing: activeTask.category))")
            } catch {
                fatalError("#\(#function): error: \(error)")
            }
        }
    }
    
    func mergeDefaultsAndWait(possibleDuplicates: [NSManagedObjectID]) {
        /**
         Make any store changes on a background context with the transaction author name of this app.
         Use performAndWait to serialize the steps. historyQueue runs in the background so this doesn't block the main queue.
         */
        let taskContext = persistentContainer.newTaskContext()
        taskContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        taskContext.performAndWait {
            do {
                try possibleDuplicates.forEach { objectID in
                    try mergeIfDefault(objectID: objectID, context: taskContext)
                }
                taskContext.saveAndLogError()
            } catch {
                ALog(level: .error, "\(#function) failed to merge defaults: \(error)")
            }
        }
    }
    
    func mergeDefaultsLater() {
        ALog()
        DispatchQueue.global(qos: .background).async {
            let taskContext = self.persistentContainer.newTaskContext()
            taskContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            taskContext.performAndWait {
                do {
                    try self.mergeHistories(taskContext)
                    taskContext.saveAndLogError()
                } catch {
                    ALog(level: .error, "\(#function) failed to merge defaults: \(error)")
                }
            }
        }
    }
    
    func mergeIfDefault(objectID: NSManagedObjectID, context: NSManagedObjectContext) throws {
        let object = context.object(with: objectID)
        if object is History {
            // TODO deal with someone elses History
            try mergeHistories(context)
        }
    }
    
    func mergeHistories(_ context: NSManagedObjectContext) throws {
        // For now, simple check if there are two history entries
        let container = self.persistentCloudKitContainer
        let request = History.fetchRequest()
        let histories = try request.execute()
        if histories.count > 1 {
            // Find oldest shared or just oldest history
            var best: History? = nil
            var bestHasShare = false
            var bestCreationDate: Date? = nil
            for history in histories {
                let hasShare = getShare(for: history) != nil
                let record = container.record(for: history.objectID)
                let creationDate = record?.creationDate
                if best == nil {
                    best = history
                    bestHasShare = hasShare
                    bestCreationDate = creationDate
                } else {
                    var replaceAsBest = false
                    if hasShare {
                        if bestHasShare {
                            replaceAsBest = checkIf(date: creationDate, isOlderThan: bestCreationDate)
                        } else {
                            replaceAsBest = true
                        }
                    } else {
                        if bestHasShare {
                            replaceAsBest = false
                        } else {
                            replaceAsBest = checkIf(date: creationDate, isOlderThan: bestCreationDate)
                        }
                    }
                    if replaceAsBest {
                        best = history
                        bestHasShare = hasShare
                        bestCreationDate = creationDate
                    }
                }
            }
            // We have a best, merge the others' entries into it
            ALog("merging one History into a better one")
            guard let best = best else {
                ALog(level: .warning, "no best History error")
                return
            }
            for history in histories {
                if history == best {
                    continue
                }
                guard let categories = history.categories else {
                    ALog(level: .warning, "no categories to merge into best history")
                    context.delete(history)
                    continue
                }
                for case let category as Category in categories {
                    if let bestCategory = best.getCategoryLike(category) {
                        // category needs merge
                        ALog(level: .info, "merge found duplicate category titled: \(category.title ?? "nil")")
                        guard let tasks = category.tasks else {
                            ALog(level: .warning, "no tasks to merge into best category")
                            continue
                        }
                        for case let task as Task in tasks {
                            if let bestTask = bestCategory.getTaskLike(task) {
                                // task needs merge
                                ALog(level: .info, "merge found duplicate task titled: \(task.title ?? "nil")")
                                guard let entries = task.pomodoroEntries else {
                                    ALog(level: .warning, "no pomodoro entries to merge into best task")
                                    continue
                                }
                                for case let entry as PomodoroEntry in entries {
                                    if bestTask.getPomodoroLike(entry) != nil {
                                        // task already has a similar enough entry, can skip
                                        ALog(level: .info, "merge found duplicate pomodoro entry")
                                        continue
                                    }
                                    bestTask.addToPomodoroEntries(entry.clone(into: context))
                                }
                            } else {
                                // can simply deep copy task
                                bestCategory.addToTasks(task.clone(into: context))
                            }
                        }
                    } else {
                        // can simply deep copy category
                        best.addToCategories(category.clone(into: context))
                    }
                }
                ALog("Deleting history entry")
                context.delete(history)
            }
        }
    }
    
    func checkIf(date: Date?, isOlderThan other: Date?) -> Bool {
        if date != nil {
            if other != nil {
                return date! < other!
            }
            return true
        }
        return false
    }
    
    func startOver() {
        let container = persistentCloudKitContainer
        let taskContext = container.newTaskContext()
        taskContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        taskContext.perform {
            do {
                try self.deleteAll(PomodoroEntry.fetchRequest(), taskContext)
                try self.deleteAll(Task.fetchRequest(), taskContext)
                try self.deleteAll(Category.fetchRequest(), taskContext)
                try self.deleteAll(History.fetchRequest(), taskContext)
                try taskContext.save()
            } catch {
                fatalError("#\(#function): error: \(error)")
            }
        }
    }
    
    private func deleteAll<T: NSManagedObject>(
        _ request: NSFetchRequest<T>,
        _ context: NSManagedObjectContext
    ) throws
    {
        let entries = try request.execute()
        for entry in entries {
            context.delete(entry)
        }
        ALog("deleted \(entries.count) of \(T.entity().name ?? "unnamed entity")")
    }
    
    func printEntityCounts() {
        let container = persistentCloudKitContainer
        let taskContext = container.newTaskContext()
        taskContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        taskContext.performAndWait {
            do {
                let model = container.managedObjectModel
                for (entityName, _) in model.entitiesByName {
                    let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                    let count = try taskContext.count(for: request)
                    ALog("CoreData has \(count) of \(entityName)")
                }
                let request = PomodoroEntry.fetchRequest()
                request.predicate = NSPredicate(format: "task == nil")
                let count = try taskContext.count(for: request)
                ALog("CoreData has \(count) orphaned PomodoroEntry objects")
            } catch {
                ALog(level: .error, "\(#function) failed to get entity counts: \(error)")
            }
        }
    }

    func fetchShareMetadata(for shareURLs: [URL],
        completion: @escaping (Result<[URL: CKShare.Metadata], Error>) -> Void)
    {
        var cache = [URL: CKShare.Metadata]()
            
        // Create the fetch operation using the share URLs that
        // the caller provides to the method.
        let operation = CKFetchShareMetadataOperation(shareURLs: shareURLs)
            
        // To reduce network requests, request that CloudKit
        // includes the root record in the metadata it returns.
        operation.shouldFetchRootRecord = true
            
        // Cache the metadata that CloudKit returns using the
        // share URL. This implementation ignores per-metadata
        // fetch errors and handles any errors in the completion
        // closure instead.
        operation.perShareMetadataResultBlock = { url, result in
            switch result {
            case .success(let metadata):
                cache[url] = metadata
            default:
                ALog("No metadata")
            }
        }
            
        // If the operation fails, return the error to the caller.
        // Otherwise, return the array of participants.
        operation.fetchShareMetadataResultBlock = { result in
            switch result {
            case .success(_):
                completion(.success(cache))
            case .failure(let error):
                completion(.failure(error))
            }
        }
            
        // Set an appropriate QoS and add the operation to the
        // container's queue to execute it.
        operation.qualityOfService = .background
        CKContainer.default().add(operation)
    }
}
