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
    
extension NSPersistentCloudKitContainer {
    #if os(iOS)
    /**
     Fetch and return shares in the persistent stores.
     */
    func fetchShares(in persistentStores: [NSPersistentStore]) throws -> [CKShare] {
        var results = [CKShare]()
        for persistentStore in persistentStores {
            do {
                let shares = try fetchShares(in: persistentStore)
                results += shares
            } catch let error {
                ALog(level: .error, "(\(#function) failed to fetch shares in \(persistentStore).")
                throw error
            }
        }
        return results
    }
    #endif
}

extension NSManagedObjectContext {
    func saveAndLogError() {
        do {
            try save()
        } catch {
            ALog(level: .error, "Failed to save Core Data context: \(error)")
        }
    }
}
