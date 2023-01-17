//
//  Persistence+PomodoroEntry.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 23/12/2022.
//

import Foundation
import CoreData
import CloudKit

extension PersistenceController {

    func addPomodoroEntry(
        timeSeconds: Double,
        timerType: String,
        stage: Int,
        startDate: Date = Date(),
        pausedAndAdjusted: Int32? = nil,
        context: NSManagedObjectContext)
    {
        context.perform {
            let entry = PomodoroEntry(context: context)
            entry.startDate = startDate
            entry.stage = Int64(stage)
            entry.timerType = timerType
            entry.timeSeconds = timeSeconds
            if let adjustedBy = pausedAndAdjusted {
                entry.pauseDate = startDate
                entry.adjustmentSeconds = Double(adjustedBy)
            }
            if let task = self.getActiveTask(context: context) {
                entry.task = task
                ALog("Creating new PomodoroEntry with task \(task)")
            } else {
                ALog(level: .warning, "No active task to add new PomodoroEntry to")
                let request = Task.fetchRequest()
                request.predicate = NSPredicate(format: "title == nil")
                do {
                    let entries = try request.execute()
                    switch entries.count {
                    case 0:
                        ALog(level: .warning, "No default task available when creating new PomorodoEntry")
                    case 1:
                        ALog("Creating new PomodoroEntry with task \(entries[0])")
                        self.activeTaskId = entries[0].objectID
                        entry.task = entries[0]
                    default:
                        ALog(level: .warning, "Multiple default tasks available when creating new PomodoroEntry, using task \(entries[0])")
                        self.activeTaskId = entries[0].objectID
                        entry.task = entries[0]
                    }
                } catch {
                    ALog(level: .error, "Failed to save Core Data context for PomodoroEntry: \(error)")
                }
            }
            
            do {
                try context.save()
            } catch {
                ALog(level: .error, "Failed to save Core Data context for PomodoroEntry: \(error)")
            }
        }
    }
    
    // Functions starting with do... are more low-level and can make
    // some assumptions that the caller has made any required checks
    // to see if this is a valid thing to do. These doAdd... functions
    // in particular do not check if multiple entries are added with
    // the same info and they assume being inside a context.perform block
    func doAddTask(
        title: String? = nil,
        category: Category? = nil,
        context: NSManagedObjectContext
    ) throws -> Task
    {
        let task = Task(context: context)
        if let category = category {
            task.category = category
        } else if self.getActiveTask(context: context)?.category != nil{
            task.category = self.getActiveTask(context: context)?.category
        } else {
            task.category = try self.getOrCreateDefaultCategory(context)
        }
        return task
    }
    
    func getOrCreateDefaultCategory(_ context: NSManagedObjectContext) throws -> Category
    {
        let categoryRequest = Category.fetchRequest()
        categoryRequest.predicate = NSPredicate(format: "title == nil")
        let categories = try categoryRequest.execute()
        if categories.count > 0 {
            if categories.count > 1 {
                ALog(level: .warning, "incorrect default category count: \(categories.count)")
            }
            return categories[0]
        }
        return try doAddCategory(context: context)
    }
    
    func doAddCategory(
        history: History? = nil,
        context: NSManagedObjectContext
    ) throws -> Category
    {
        let category = Category(context: context)
        if let history = history {
            category.history = history
        } else if self.getActiveTask(context: context)?.category?.history != nil {
            category.history = self.getActiveTask(context: context)?.category?.history
        } else {
            let historyRequest = History.fetchRequest()
            // TODO handle situation when other people's history is also relevant
            let histories = try historyRequest.execute()
            if histories.count > 0 {
                if histories.count > 1 {
                    ALog(level: .warning, "incorrect history entry count: \(histories.count)")
                }
                category.history = histories[0]
            } else {
                category.history = try doAddHistory(context: context)
            }
        }
        return category
    }
    
    func doAddHistory(
        ownerName: String? = nil,
        allowReactions: Bool = true,
        allowComments: Bool = true,
        context: NSManagedObjectContext
    ) throws -> History
    {
        let history = History(context: context)
        history.ownerName = ownerName
        history.allowReactions = allowReactions
        history.allowComments = allowComments
        return history
    }
            
    /*
    func updatePomodoroShares() {
        let fetchRequest = PomodoroEntry.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]
        fetchRequest.predicate = NSPredicate(format:"startDate != nil AND timerType == 'pomodoro'", NSDate())
        
        let container = persistentCloudKitContainer
        let taskContext = container.newTaskContext()
        taskContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        taskContext.performAndWait {
            do {
                let entries = try fetchRequest.execute()
                let shareDict = try container.fetchShares(matching: entries.map{ $0.objectID })
                var alreadySharedCount = 0
                var shareConflictCount = 0
                var unsharedEntries = [NSManagedObject]()
                for entry in entries {
                    let share = shareDict[entry.objectID]
                    if share != nil {
                        alreadySharedCount += 1
                        if self.pomodoroHistoryShare == nil {
                            self.pomodoroHistoryShare = share
                            ALog("share publicPermission: \(share!.publicPermission)")
                        } else {
                            if share?.title != self.pomodoroHistoryShare?.title {
                                shareConflictCount += 1
                            }
                        }
                        continue
                    }
                    unsharedEntries.append(entry)
                }
                ALog("updatePomodoroShares alreadyShared:\(alreadySharedCount) conflicts:\(shareConflictCount)")
                if unsharedEntries.isEmpty {
                    ALog("updatePomodoroShares no unshared entries")
                    return
                }
                self.sharePomodoroHistoryEntries(unsharedEntries)
            } catch {
                fatalError("#\(#function): error: \(error)")
            }
        }
    }
    */
    
    private func sharePomodoroHistoryEntries(_ unsharedEntries: [NSManagedObject]) {
        self.shareObjects(unsharedEntries, to: self.pomodoroHistoryShare) {
            share, error in
            if error != nil {
                ALog(level: .error, "updatePomodoroShares failed to share unshared entries with error: \(error!)")
                return
            }
            if self.pomodoroHistoryShare == nil {
                self.pomodoroHistoryShare = share
            }
            ALog("shared \(unsharedEntries.count) new entries")
        }
    }
}
