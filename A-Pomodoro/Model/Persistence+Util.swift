//
//  Persistence+Util.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 21/01/2023.
//

import Foundation
import CoreData

extension PersistenceController {

    func performAndWait(_ block: (NSManagedObjectContext) -> Void) {
        let taskContext = persistentContainer.newTaskContext()
        taskContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        taskContext.performAndWait {
            block(taskContext)
        }
    }

}
