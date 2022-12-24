//
//  Persistence+PomodoroEntry.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 23/12/2022.
//

import Foundation
import CoreData

extension PersistenceController {
    func addPomodoroEntry(
        timeSeconds: Double,
        timerType: String,
        stage: Int,
        startDate: Date = Date(),
        context: NSManagedObjectContext)
    {
        context.perform {
            let entry = PomodoroEntry(context: context)
            entry.startDate = startDate
            entry.stage = Int64(stage)
            entry.timerType = timerType
            entry.timeSeconds = timeSeconds
            
            do {
                try context.save()
            } catch {
                print("Failed to save Core Data context for PomodoroEntry: \(error)")
            }
        }
    }
        
}
