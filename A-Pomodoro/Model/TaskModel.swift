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

class TaskModel: NSObject, NSFetchedResultsControllerDelegate, ObservableObject {

    @Published var completingTask: TempTask? = nil
    @Published public private(set) var reminderCategories: [TempCategory] = [] {
        didSet {
            calcMergedCategories()
        }
    }
    @Published public private(set) var myCategories: [Category] = [] {
        didSet {
            calcMergedCategories()
        }
    }
    @Published public private(set) var mergedCategories: [TempCategory] = []
    
    private func calcMergedCategories() {
        var retval = [TempCategory]()
        // First add incomplete reminders in order
        for tempCat in self.reminderCategories {
            var tempTasks = [TempTask]()
            for tempTask in tempCat.tasks {
                if tempTask.status == .todo {
                    tempTasks.append(tempTask)
                }
            }
            if tempTasks.isEmpty {
                continue
            }
            retval.append(TempCategory(title: tempCat.title, tasks: tempTasks))
        }
        // Add categories and tasks that have completed pomodoros
        for cat in self.myCategories {
            guard let tasks = cat.tasks else {
                continue
            }
            if let i = retval.firstIndex(where: { $0.title == cat.title }) {
                for case let task as Task in tasks {
                    if !retval[i].tasks.contains(where: { $0.title == task.title }) {
                        retval[i].tasks.append(TempTask(task: task))
                    }
                }
            } else {
                var tempTasks = [TempTask]()
                for case let task as Task in tasks {
                    tempTasks.append(TempTask(task: task))
                }
                if tempTasks.isEmpty {
                    continue
                }
                retval.append(TempCategory(title: cat.title ?? .defaultCategory, tasks: tempTasks))
            }
        }
        // Change status to .completed for completed reminders that have pomodoros
        for tempCat in self.reminderCategories {
            if let i = retval.firstIndex(where: { $0.title == tempCat.title }) {
                for tempTask in tempCat.tasks {
                    if tempTask.status == .completed,
                        let j = retval[i].tasks.firstIndex(where: { $0.title == tempTask.title })
                    {
                        retval[i].tasks[j].status = .completed
                    }
                }
            }
        }
        self.mergedCategories = retval
    }
    
    /*
    var mergedCategories: AnyPublisher<[TempCategory], Never> {
        Publishers
            .CombineLatest($reminderCategories, $myCategories)
            .map {
                tuple in
                let reminderCategories = tuple.0
                let myCategories = tuple.1
                var retval = [TempCategory]()
                // First add incomplete reminders in order
                for tempCat in reminderCategories {
                    var tempTasks = [TempTask]()
                    for tempTask in tempCat.tasks {
                        if tempTask.status == .todo {
                            tempTasks.append(tempTask)
                        }
                    }
                    if tempTasks.isEmpty {
                        continue
                    }
                    retval.append(TempCategory(title: tempCat.title, tasks: tempTasks))
                }
                // Add categories and tasks that have completed pomodoros
                for cat in myCategories {
                    guard let tasks = cat.tasks else {
                        continue
                    }
                    if let i = retval.firstIndex(where: { $0.title == cat.title }) {
                        for case let task as Task in tasks {
                            if !retval[i].tasks.contains(where: { $0.title == task.title }) {
                                retval[i].tasks.append(TempTask(task: task))
                            }
                        }
                    } else {
                        var tempTasks = [TempTask]()
                        for case let task as Task in tasks {
                            tempTasks.append(TempTask(task: task))
                        }
                        if tempTasks.isEmpty {
                            continue
                        }
                        retval.append(TempCategory(title: cat.title ?? .defaultCategory, tasks: tempTasks))
                    }
                }
                // Change status to .completed for completed reminders that have pomodoros
                for tempCat in reminderCategories {
                    if let i = retval.firstIndex(where: { $0.title == tempCat.title }) {
                        for tempTask in tempCat.tasks {
                            if tempTask.status == .completed,
                                let j = retval[i].tasks.firstIndex(where: { $0.title == tempTask.title })
                            {
                                retval[i].tasks[j].status = .completed
                            }
                        }
                    }
                }
                return retval
            }.eraseToAnyPublisher()
    }
    */

    private let categoriesController: NSFetchedResultsController<Category>
    private let fetchRequest: NSFetchRequest<Category>



    init(container: NSPersistentContainer) {
        let context = container.viewContext
        
        self.fetchRequest = Category.fetchRequest()
        self.fetchRequest.sortDescriptors = [NSSortDescriptor(key: "title", ascending: false)]
        self.categoriesController = NSFetchedResultsController(
            fetchRequest: self.fetchRequest,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil)
        super.init()
        categoriesController.delegate = self
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.postinit(container)
        }
    }

    private func postinit(_ container: NSPersistentContainer) {
        assert(Thread.isMainThread)
        do {
            try categoriesController.performFetch()
        } catch {
            let error = error as NSError
            fatalError("Unresolved error \(error), \(error.userInfo)")
        }
        maybeUpdateCategories()
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        ALog("updating")
        maybeUpdateCategories()
    }
    
    private func maybeUpdateCategories() {
        if let objects = self.categoriesController.fetchedObjects {
            if !objects.isEmpty {
                self.myCategories = objects.filter { $0.isMine }
            }
        }
    }

    private func setReminderCategories(_ cats: [TempCategory]) {
        DispatchQueue.main.async {
            self.reminderCategories = cats
        }
    }

    func updateReminderCategories() {
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
                        self.setReminderCategories(tempCats)
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
                    self.setReminderCategories(tempCats)
                }
            })
        }
    }
    
    static func completeTask(task: Task?, activateNext: Bool, callback: @escaping (CompleteTaskCallback) -> Void) {
        guard let taskTitle = task?.title,
            let categoryTitle = task?.category?.title
        else {
            ALog(level: .warning, "No task to complete")
            callback(.fail)
            return
        }
        completeTask(taskTitle: taskTitle, categoryTitle: categoryTitle, activateNext: activateNext, callback: callback)
    }
    
    static func completeTask(taskTitle: String, categoryTitle: String, activateNext: Bool, callback: @escaping (CompleteTaskCallback) -> Void) {
        let store = EKEventStore()
        let reminderLists = store.calendars(for: .reminder)
        guard let list = reminderLists.first(where: { $0.title == categoryTitle }) else {
            ALog(level: .warning, "No Reminders List matching \(categoryTitle)")
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
                } else if title == taskTitle {
                    match = reminder
                }
            }
            
            ALog("Completing reminder task \(match?.title ?? "nil")")
            ALog("Moving on to reminder task \(next?.title ?? "nil")")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                if let next = next {
                    let controller = PersistenceController.active
                    controller.applyActiveTask(controller.persistentContainer.viewContext, taskTitle: next.title, categoryTitle: categoryTitle)
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
