//
//  Task+Util.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 16/01/2023.
//

import Foundation
import CoreData

extension Task {

    func getPomodoroLike(_ dup: PomodoroEntry) -> PomodoroEntry? {
        guard let pomodoroEntries = self.pomodoroEntries else {
            return nil
        }
        for case let entry as PomodoroEntry in pomodoroEntries {
            if dup.startDate == entry.startDate
                && dup.timerType == entry.timerType
            {
                return entry
            }
        }
        return nil
    }
    
    func clone(into context: NSManagedObjectContext) -> Task {
        let clone = Task(context: context)
        
        for (key, _) in Task.entity().attributesByName {
            clone.setValue(self.value(forKey: key), forKey: key)
        }

        if let pomodoroEntries = self.pomodoroEntries {
            for case let entry as PomodoroEntry in pomodoroEntries {
                clone.addToPomodoroEntries(entry.clone(into: context))
            }
        }
        
        return clone
    }
    
    public override var description: String {
        return self.title ?? "Default"
    }
    
}
