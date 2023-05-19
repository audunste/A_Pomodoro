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

    func getOwnHistory() -> History? {
        let request = History.fetchRequest()
        do {
            let histories = try request.execute()
            for history in histories {
                if let share = getShare(for: history) {
                    if share.owner == share.currentUserParticipant {
                        return history
                    }
                    continue
                }
                return history
            }
        } catch {
            ALog(level: .error, "Error getting own history \(error)")
        }
        return nil
    }
    
    // Note: Expects to be performed on a CoreData context (same as one given)
    func getAssignOrCreateActiveTask(context: NSManagedObjectContext) -> Task? {
        if let task = self.getActiveTask(context: context) {
            return task
        }
        let request = Task.fetchRequest()
        request.predicate = NSPredicate(format: "title == nil")
        do {
            let unfilteredEntries = try request.execute()
            let entries = unfilteredEntries.filter { $0.isMine }
            switch entries.count {
            case 0:
                ALog(level: .info, "No default task available. Creating it.")
                return try doAddTask(context: context)
            case 1:
                self.activeTaskId = entries[0].objectID
                return entries[0]
            default:
                ALog(level: .warning, "Multiple default tasks available, using task \(entries[0])")
                self.activeTaskId = entries[0].objectID
                return entries[0]
            }
        } catch {
            ALog(level: .error, "Failed to get tasks: \(error)")
        }
        return nil
    }

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
            if let task = self.getAssignOrCreateActiveTask(context: context) {
                entry.task = task
                ALog("Creating new PomodoroEntry with task \(task)")
            } else {
                ALog(level: .warning, "No default task available when creating new PomorodoEntry")
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
        task.title = title
        if let category = category {
            task.category = category
        } else if self.getActiveTask(context: context)?.category != nil {
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
        let unfilteredCategories = try categoryRequest.execute()
        let categories = unfilteredCategories.filter { $0.isMine }
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
            category.history = try self.getOrCreateOwnHistory(context)
        }
        return category
    }
    
    func getOrCreateOwnHistory(_ context: NSManagedObjectContext) throws -> History {
        let historyRequest = History.fetchRequest()
        let unfilteredHistories = try historyRequest.execute()
        let histories = unfilteredHistories.filter { $0.isMine }
        if histories.count > 0 {
            if histories.count > 1 {
                ALog(level: .warning, "incorrect history entry count: \(histories.count)")
            }
            return histories[0]
        }
        return try doAddHistory(context: context)
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
            
}
