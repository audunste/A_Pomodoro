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
            
            do {
                try context.save()
                if timerType == TimerType.pomodoro.rawValue {
                    if self.pomodoroHistoryShare != nil {
                        self.sharePomodoroHistoryEntries([entry])
                    } else {
                        self.updatePomodoroShares()
                    }
                }
            } catch {
                print("Failed to save Core Data context for PomodoroEntry: \(error)")
            }
        }
    }
            
    func updatePomodoroShares() {
        let fetchRequest = PomodoroEntry.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: true)]
        fetchRequest.predicate = NSPredicate(format:"startDate != nil AND timerType == 'pomodoro'", NSDate())
        
        let container = persistentCloudKitContainer
        let taskContext = container.newTaskContext()
        taskContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        
        taskContext.perform {
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
                        } else {
                            if share?.title != self.pomodoroHistoryShare?.title {
                                shareConflictCount += 1
                            }
                        }
                        continue
                    }
                    unsharedEntries.append(entry)
                }
                print("apom updatePomodoroShares alreadyShared:\(alreadySharedCount) conflicts:\(shareConflictCount)")
                if unsharedEntries.isEmpty {
                    print("apom updatePomodoroShares no unshared entries")
                    return
                }
                self.sharePomodoroHistoryEntries(unsharedEntries)
            } catch {
                fatalError("#\(#function): apom error: \(error)")
            }
        }
    }
    
    private func sharePomodoroHistoryEntries(_ unsharedEntries: [NSManagedObject]) {
        self.shareObjects(unsharedEntries, to: self.pomodoroHistoryShare) {
            share, error in
            if error != nil {
                print("apom updatePomodoroShares failed to share unshared entries with error: \(error!)")
                return
            }
            if self.pomodoroHistoryShare == nil {
                self.pomodoroHistoryShare = share
            }
            print("apom shared \(unsharedEntries.count) new entries")
        }
    }
}
