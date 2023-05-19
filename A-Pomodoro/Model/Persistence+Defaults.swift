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

    /*
    func makeSureDefaultsExist() {
        performAndWait { taskContext in
            do {
                
                let request = Task.fetchRequest()
                let count = try taskContext.count(for: request)
                if count > 0 && getOwnHistory() != nil {
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
    */
    
    func fixDefaultTask() {
        performAndWait { taskContext in
            do {
                let request = Task.fetchRequest()
                let allTasks = try request.execute()
                for task in allTasks {
                    ALog("task: \(task) \(task.isMine)")
                }
            } catch {
                fatalError("#\(#function): error: \(error)")
            }
        }
    }
        
    func logObjectTree() {
        performAndWait { taskContext in
            do {
                let request = History.fetchRequest()
                let histories = try request.execute()
                for history in histories {
                    ALog("\(history.isMine ? "M" : "S") \(history)")
                    if let share = PersistenceController.shared.getShare(for: history) {
                        ALog("  \(share.owner)")
                    }
                    guard let container = PersistenceController.shared.persistentCloudKitContainer else {
                        continue
                    }
                    let sharesByID = try container.fetchShares(matching: [history.objectID])
                    if sharesByID.count > 0 {
                        ALog("  \(sharesByID[history.objectID]!)")
                    }
                    
                    guard let categories = history.categories else {
                        continue
                    }
                    for case let category as Category in categories {
                        ALog("\(category.isMine ? "M" : "S")   \(category)")
                        guard let tasks = category.tasks else {
                            continue
                        }
                        for case let task as Task in tasks {
                            ALog("\(task.isMine ? "M" : "S")     \(task)")
                            guard let pomodoros = task.pomodoroEntries else {
                                continue
                            }
                            ALog("      entryCount: \(pomodoros.count)")
                        }
                    }
                }
            } catch {
                fatalError("#\(#function): error: \(error)")
            }
        }
    }
    
    func adoptOrphanedPomodoros() {
        performAndWait { taskContext in
            do {
                let request = PomodoroEntry.fetchRequest()
                request.predicate = NSPredicate(format: "task == nil")
                let count = try taskContext.count(for: request)
                if count > 0 {
                    ALog("Adopting \(count) orphaned PomodoroEntry objects")
                    let pomodoros = try request.execute()
                    guard let activeTask = getAssignOrCreateActiveTask(context: taskContext) else {
                        ALog("No active task to adopt orphans")
                        return
                    }
                    for pomodoro in pomodoros {
                        pomodoro.task = activeTask
                    }
                    taskContext.saveAndLogError()
                }
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
    
    func testShareOfHistory() {
        performAndWait { taskContext in
            do {
                guard let cloudKitContainer = persistentContainer as? NSPersistentCloudKitContainer else {
                    return
                }
                let history2 = History(context: taskContext)
                taskContext.saveAndLogError()
                
                prepareShare(for: history2) {
                    share in
                    guard let share = share else {
                        taskContext.delete(history2)
                        taskContext.saveAndLogError()
                        return
                    }
                    cloudKitContainer.persistUpdatedShare(share, in: self.privatePersistentStore) { (share, error) in
                        if let error = error {
                            ALog(level: .error, "Failed to persist updated share: \(error)")
                        } else {
                            ALog("Share success")
                        }
                        taskContext.delete(history2)
                        taskContext.saveAndLogError()
                        return
                    }
                }
            } catch {
                fatalError("#\(#function): error: \(error)")
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
                let model = persistentContainer.managedObjectModel
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
    
    func deleteReciprocateObjects() {
        performAndWait { taskContext in
            let request = History.fetchRequest()
            guard let histories = try? request.execute()
            else {
                ALog(level: .warning, "Could not get History objects")
                return
            }
            for history in histories {
                guard let reciprocations = history.reciprocations,
                    let share = self.getShare(for: history),
                    let lookupInfoHash = share.currentUserParticipant?.userIdentity.lookupInfo?.sha256Hash
                else { continue }
                let removeArray = reciprocations.filter { ($0 as! Reciprocate).lookupInfoHash == lookupInfoHash }
                for toRemove in removeArray {
                    taskContext.delete(toRemove as! Reciprocate)
                }
            }
            taskContext.saveAndLogError()
        }
    }
    
    func resetReciprocation() {
        performAndWait { taskContext in
            do {
                try getOwnersWhoHaveSharedWithMe { result in
                    switch result {
                    case .success(let participants):
                        ALog("maybe reset: \(participants)")
                        if participants.isEmpty {
                            return
                        }
                        self.resetReciprocation(participants)
                    case .failure(let error):
                        ALog(level: .error, "Failed to get owners who shared with me: \(error)")
                    }
                }
            } catch {
                ALog(level: .error, "\(#function) failed to get entity counts: \(error)")
            }
        }
    }

    func resetReciprocation(_ participants: [CKShare.Participant]) {
        performAndWait { taskContext in
            guard let history = getOwnHistory() else {
                ALog(level: .warning, "Couldn't get own history")
                return
            }
            if let share = getShare(for: history) {
                configure(share: share, with: history)
                resetReciprocation(participants, share)
            }
        }
    }
    
    func resetReciprocation(_ participants: [CKShare.Participant], _ share: CKShare) {
        guard let container = persistentCloudKitContainer else {
            return
        }
        let participants = share.participants.filter { participantInShare in
            return participantInShare.role != .owner && participants.contains { participantToMaybeRemove in
                guard let li0 = participantInShare.userIdentity.lookupInfo,
                    let li1 = participantToMaybeRemove.userIdentity.lookupInfo else
                {
                    return false
                }
                if li0 == li1 {
                    if participantInShare.acceptanceStatus == .pending {
                        return true
                    }
                }
                return false
            }
        }
        if participants.isEmpty {
            ALog("No participants need reset")
            return
        }
        for participant in participants {
            ALog("Remove participant \(participant) from share")
            share.removeParticipant(participant)
        }
        container.persistUpdatedShare(share, in: self.privatePersistentStore) { (share, error) in
            if let error = error {
                ALog(level: .error, "Failed to persist updated share: \(error)")
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
        guard let container = persistentCloudKitContainer else {
            return
        }
        let participants = participants.filter { participantToAdd in
            return !share.participants.contains { participantInShare in
                guard let li0 = participantInShare.userIdentity.lookupInfo,
                    let li1 = participantToAdd.userIdentity.lookupInfo else
                {
                    return false
                }
                if li0 == li1 {
                    ALog("Already reciprocated to \(li0)")
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
        container.persistUpdatedShare(share, in: self.privatePersistentStore) { (share, error) in
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
        completion: @escaping (Result<[CKShare.Participant], Error>) -> Void)
    {
        ALog("lookupInfos.count: \(lookupInfos.count)")
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
        // TODO(audun) This one can take 3 minutes to complete for no apparent reason sometimes, so should try to get by without it
        ALog("shareURLs.count: \(shareURLs.count)")
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
            ALog("perShareMetadataResultBlock \(result)")
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
            ALog("fetchShareMetadataResultBlock \(result)")
            switch result {
            case .success(_):
                completion(.success(cache))
            case .failure(let error):
                completion(.failure(error))
            }
        }
            
        // Set an appropriate QoS and add the operation to the
        // container's queue to execute it.
        operation.qualityOfService = .userInitiated
        CKContainer.default().add(operation)
    }
    
    func logShareParticipants() {
        performAndWait { taskContext in
            guard let history = getOwnHistory() else {
                return
            }
            ALog("reciprocations.count: \(history.reciprocations?.count ?? 0)")
            ALog("categories.count: \(history.categories?.count ?? 0)")
            if let share = getShare(for: history) {
                for participant in share.participants {
                    ALog("participant: \(participant)")
                }
            }            
        }
    }
    
    func unshareOwnHistory() {
        performAndWait { taskContext in
            guard let history = getOwnHistory() else {
                return
            }
            if let _ = getShare(for: history) {
                ALog("Found share will clone and delete")
                
                _ = history.clone(into: taskContext)
                taskContext.delete(history)
                
                taskContext.saveAndLogError()
            }
        }
    }
    
    func deleteAllOwnObjects() {
        performAndWait { taskContext in
            guard let history = getOwnHistory() else {
                return
            }
            taskContext.delete(history)
            taskContext.saveAndLogError()
        }
        performAndWaitFatalError { taskContext in
            let allCategories = try Category.fetchRequest().execute()
            let myCategories = allCategories.filter { $0.isMine }
            for category in myCategories {
                taskContext.delete(category)
            }
            for task in try Task.fetchRequest().execute().filter({ $0.isMine }) {
                taskContext.delete(task)
            }
            for entry in try PomodoroEntry.fetchRequest().execute().filter({ $0.isMine }) {
                taskContext.delete(entry)
            }
            taskContext.saveAndLogError()
        }
    }
    
}
