//
//  TaskModel.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 16/05/2023.
//

import Combine
import Foundation
import CoreData
import CloudKit
import EventKit

enum CompleteTaskCallback {
    case fail
    case processing
    case complete
}

class TaskModel: ObservableObject {

    @Published var reminderCategories: [TempCategory] = []

    private var _viewContext: NSManagedObjectContext?
    var viewContext: NSManagedObjectContext? {
        set {
            _viewContext = newValue
            updateCategories()
        }
        get {
            return _viewContext
        }
    }

    init(viewContext: NSManagedObjectContext? = nil) {
        self.viewContext = viewContext
    }
    
    func updateCategories() {
        let authStatus = EKEventStore.authorizationStatus(for: .reminder)
        if authStatus != .authorized {
            return
        }
        let store = EKEventStore()
        let reminderLists = store.calendars(for: .reminder)
        var tempCats = [TempCategory]()
        for list in reminderLists {
            //let pred = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: [list])
            let pred = store.predicateForReminders(in: [list])
            var tempCat = TempCategory(title: list.title, tasks: [])
            store.fetchReminders(matching: pred, completion: {(_ reminders: [Any]?) -> Void in
                guard let reminders = reminders as? [EKReminder?] else {
                    ALog("Did not get EKReminder list from fetchReminders")
                    tempCats.append(tempCat)
                    if tempCats.count == reminderLists.count {
                        self.reminderCategories = tempCats
                    }
                    return
                }
                for reminder: EKReminder? in reminders {
                    // Do something for each reminder.
                    guard let reminder = reminder,
                        let _ = reminder.title
                    else {
                        ALog("Reminder is nil")
                        continue
                    }
                    tempCat.tasks.append(TempTask(reminder: reminder))
                }
                tempCats.append(tempCat)
                if tempCats.count == reminderLists.count {
                    self.reminderCategories = tempCats
                }
            })
        }
    }
    
    static func completeTask(task: Task?, activateNext: Bool, callback: @escaping (CompleteTaskCallback) -> Void) {
        guard let task = task else {
            ALog(level: .warning, "No task to complete")
            callback(.fail)
            return
        }
        let store = EKEventStore()
        let reminderLists = store.calendars(for: .reminder)
        guard let list = reminderLists.first(where: { $0.title == task.category?.title }) else {
            ALog(level: .warning, "No Reminders List matching \(task.category?.title ?? "nil")")
            callback(.fail)
            return
        }
        callback(.processing)
        let pred = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: [list])
        store.fetchReminders(matching: pred, completion: {(_ reminders: [Any]?) -> Void in
            guard let reminders = reminders as? [EKReminder?] else {
                ALog("Did not get EKReminder list from fetchReminders")
                callback(.fail)
                return
            }
            var match: EKReminder? = nil
            var next: EKReminder? = nil
            for reminder: EKReminder? in reminders {
                // Do something for each reminder.
                guard let reminder = reminder,
                    let title = reminder.title
                else {
                    ALog("Reminder is nil")
                    continue
                }
                if match != nil && next == nil && activateNext {
                    next = reminder
                } else if title == task.title {
                    match = reminder
                }
            }
            
            ALog("Completing reminder task \(match?.title ?? "nil")")
            ALog("Moving on to reminder task \(next?.title ?? "nil")")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                if let next = next {
                    let controller = PersistenceController.active
                    controller.applyActiveTask(controller.persistentContainer.viewContext, taskTitle: next.title, categoryTitle: task.category?.title)
                    {
                        newTask in
                        ALog("Just continuing with newTask \(newTask.title ?? "default")")
                    }
                }
                if let match = match {
                    match.isCompleted = true
                    do {
                        try store.save(match, commit: true)
                        callback(.complete)
                        return
                    } catch {
                        ALog(level: .warning, "Failed to complete reminder \(match.title ?? "unnamed"): \(error)")
                    }
                }
                callback(.fail)
                return
            }
        })
    }

}
