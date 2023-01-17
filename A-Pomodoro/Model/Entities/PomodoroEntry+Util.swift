//
//  PomodoroEntry+Util.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 24/12/2022.
//

import Foundation
import CoreData

extension PomodoroEntry {

    func getRemaining(at date: Date = Date()) -> Double {
        guard let startDate = self.startDate else {
            return 0
        }
        let stopDate = self.pauseDate ?? date
        let elapsed = -startDate.timeIntervalSince(stopDate) - self.pauseSeconds - self.adjustmentSeconds
        return max(0.0, self.timeSeconds - elapsed)
    }
    
    var isPaused: Bool {
        if self.pauseDate == nil {
            return false
        }
        if self.startDate == nil {
            return false
        }
        return getRemaining() > 0
    }
    
    var isRunning: Bool {
        if self.startDate == nil {
            return false
        }
        if self.isPaused {
            return false
        }
        if self.fastForwardDate != nil {
            return false
        }
        return getRemaining() > 0
    }
    
    func clone(into context: NSManagedObjectContext) -> PomodoroEntry {
        let clone = PomodoroEntry(context: context)
        
        for (key, _) in PomodoroEntry.entity().attributesByName {
            clone.setValue(self.value(forKey: key), forKey: key)
        }

        return clone
    }
    
}
