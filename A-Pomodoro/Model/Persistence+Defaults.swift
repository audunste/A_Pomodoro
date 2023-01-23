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
        performAndWait { taskContext in
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
    
    func fixHistoryShare() {
        performAndWait { context in
            guard let history = getOwnHistory(), let share = getShare(for: history) else {
                ALog(level: .warning, "No own history")
                return
            }
            
        }
    }
    
    func mergeDefaultsAndWait(possibleDuplicates: [NSManagedObjectID]) {
        performAndWait { taskContext in
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
            try mergeHistories(context)
        }
    }
    
    func mergeHistories(_ context: NSManagedObjectContext) throws {
        // For now, simple check if there are two history entries
        let container = self.persistentCloudKitContainer
        let request = History.fetchRequest()
        let allHistories = try request.execute()
        let histories = allHistories.filter { $0.isMine }
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
        performAndWait { taskContext in
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
        performAndWait { taskContext in
            do {
                let model = persistentCloudKitContainer.managedObjectModel
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
    
    func reciprocateShares() {
        performAndWait { taskContext in
            do {
                try getOwnersWhoHaveSharedWithMe { result in
                    switch result {
                    case .success(let participants):
                        ALog("reciprocate to: \(participants)")
                        if participants.isEmpty {
                            return
                        }
                        self.reciprocateShares(participants)
                    case .failure(let error):
                        ALog(level: .error, "Failed to get owners who shared with me: \(error)")
                    }
                }
            } catch {
                ALog(level: .error, "\(#function) failed to get entity counts: \(error)")
            }
        }
    }
    
    func reciprocateShares(_ participants: [CKShare.Participant]) {
        performAndWait { taskContext in
            guard let history = getOwnHistory() else {
                ALog(level: .warning, "Couldn't get own history")
                return
            }
            if let share = getShare(for: history) {
                configure(share: share, with: history)
                reciprocateShares(participants, share)
                return
            }
            shareObject(history, to: nil) {
                share, error in
                if let share = share {
                    self.configure(share: share, with: history)
                    self.reciprocateShares(participants, share)
                }
                if let error = error {
                    ALog(level: .error, "Failed to share History: \(error)")
                }
            }
        }
    }

    func reciprocateShares(_ participants: [CKShare.Participant], _ share: CKShare) {
        let participants = participants.filter { participantToAdd in
            return !share.participants.contains { participantInShare in
                guard let li0 = participantInShare.userIdentity.lookupInfo,
                    let li1 = participantToAdd.userIdentity.lookupInfo else
                {
                    return false
                }
                return li0 == li1
            }
        }
        if participants.isEmpty {
            ALog("No participants need share reciprocate")
            return
        }
        for participant in participants {
            participant.permission = .readWrite
            ALog("Add participant \(participant) to history share")
            share.addParticipant(participant)
        }
        self.persistentCloudKitContainer.persistUpdatedShare(share, in: self.privatePersistentStore) { (share, error) in
            if let error = error {
                ALog(level: .error, "Failed to persist updated share: \(error)")
            }
        }
    }

    func getOwnersWhoHaveSharedWithMe(completion: @escaping (Result<[CKShare.Participant], Error>) -> Void) throws {
        let request = History.fetchRequest()
        var ownersThatArentMe = [CKShare.Participant]()
        var participantsIveSharedWith = [CKShare.Participant]()
        for history in try request.execute() {
            guard let share = getShare(for: history) else {
                continue
            }
            let isMe = share.owner == share.currentUserParticipant
            if isMe {
                for participant in share.participants {
                    if participant != share.currentUserParticipant
                        && participant.userIdentity.lookupInfo != nil
                    {
                        participantsIveSharedWith.append(participant)
                    }
                }
            } else {
                ownersThatArentMe.append(share.owner)
            }
        }
        for participant in participantsIveSharedWith {
            if let index = ownersThatArentMe.firstIndex(of: participant) {
                ownersThatArentMe.remove(at: index)
            }
        }
        
        // Recreate the participants as "neutral" ones
        let lookup = ownersThatArentMe.map { $0.userIdentity.lookupInfo! }
        fetchParticipants(for: lookup, completion: completion)
    }
    
    func fetchParticipants(for lookupInfos: [CKUserIdentity.LookupInfo],
        completion: @escaping (Result<[CKShare.Participant], Error>) -> Void) {

        var participants = [CKShare.Participant]()
            
        // Create the operation using the lookup objects
        // that the caller provides to the method.
        let operation = CKFetchShareParticipantsOperation(
            userIdentityLookupInfos: lookupInfos)
            
        // Collect the participants as CloudKit generates them.
        operation.perShareParticipantResultBlock = { info, result in
            switch result {
            case .failure(let error):
                ALog("error getting participant for \(info): \(error)")
            case .success(let participant):
                participants.append(participant)
            }
        }
            
        // If the operation fails, return the error to the caller.
        // Otherwise, return the array of participants.
        operation.fetchShareParticipantsResultBlock = { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(_):
                completion(.success(participants))
            }
        }
            
        // Set an appropriate QoS and add the operation to the
        // container's queue to execute it.
        operation.qualityOfService = .userInitiated
        CKContainer.default().add(operation)
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
