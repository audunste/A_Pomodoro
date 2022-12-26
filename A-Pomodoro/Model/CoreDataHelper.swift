//
//  CoreDataHelper.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 22/12/2022.
//

import CoreData
import CloudKit

/**
 A convenience method for creating background contexts that specify the app as their transaction author.
 */
extension NSPersistentContainer {
    func newTaskContext() -> NSManagedObjectContext {
        let context = newBackgroundContext()
        context.transactionAuthor = TransactionAuthor.app
        return context
    }
}

extension NSManagedObjectContext {
    func saveAndLogError() {
        do {
            try save()
        } catch {
            print("Failed to save Core Data context: \(error)")
        }
    }
}
