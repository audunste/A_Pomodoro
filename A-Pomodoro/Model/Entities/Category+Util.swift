//
//  Category+Util.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 16/01/2023.
//

import Foundation
import CoreData

extension Category {

    var isMine: Bool {
        guard let history = self.history else {
            return true
        }
        return history.isMine
    }

    func getTaskLike(_ dup: Task) -> Task? {
        guard let tasks = self.tasks else {
            return nil
        }
        for case let task as Task in tasks {
            if dup.title == task.title {
                return task
            }
        }
        return nil
    }
    
    func clone(into context: NSManagedObjectContext) -> Category {
        let clone = Category(context: context)
        
        for (key, _) in Category.entity().attributesByName {
            clone.setValue(self.value(forKey: key), forKey: key)
        }

        if let tasks = self.tasks {
            for case let task as Task in tasks {
                clone.addToTasks(task.clone(into: context))
            }
        }
        
        return clone
    }
    
    public override var description: String {
        return self.title ?? "Default"
    }
    
}
