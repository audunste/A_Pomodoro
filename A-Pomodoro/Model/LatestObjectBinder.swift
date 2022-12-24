//
//  LatestObjectBinder.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 24/12/2022.
//

import Foundation

import Foundation
import CoreData
import Combine

class LatestObjectBinder<T>: NSObject, NSFetchedResultsControllerDelegate, ObservableObject where T: NSFetchRequestResult {

    let didChange = PassthroughSubject<Void, Never>()
    private let controller: NSFetchedResultsController<T>
    private let fetchRequest: NSFetchRequest<T>
    
    @Published var managedObject: T? = nil

    init(container: NSPersistentContainer, sortKey: String) {
        let context = container.viewContext
        let entityName = "\(T.self)"
        self.fetchRequest = NSFetchRequest<T>(entityName: entityName)
        self.fetchRequest.sortDescriptors = [NSSortDescriptor(key: sortKey, ascending: false)]
        self.controller = NSFetchedResultsController(
            fetchRequest: self.fetchRequest,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil)
        super.init()
        controller.delegate = self
        if Thread.isMainThread {
            postinit(container)
        } else {
            DispatchQueue.main.async {
                self.postinit(container)
            }
        }
    }
    
    private func postinit(_ container: NSPersistentContainer) {
        assert(Thread.isMainThread)
        do {
            try controller.performFetch()
        } catch {
            let error = error as NSError
            fatalError("Unresolved error \(error), \(error.userInfo)")
        }
        if !maybeUpdateManagedObject() {
            container.viewContext.automaticallyMergesChangesFromParent = true
            container.performBackgroundTask { (bContext) in
                bContext.automaticallyMergesChangesFromParent = true
                self.maybeCreateDefaults(
                    context: bContext,
                    request: self.fetchRequest)
            }
        }
    }
    
    func deleteAllAndSave() {
        NSLog("deleteAllAndSave")
        let context = controller.managedObjectContext
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: self.fetchRequest as! NSFetchRequest<NSFetchRequestResult>)
        deleteRequest.resultType = .resultTypeObjectIDs
        
        do {
            let deleteResult = try context.execute(deleteRequest) as? NSBatchDeleteResult
            if let objectIDs = deleteResult?.result as? [NSManagedObjectID] {
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: [NSDeletedObjectsKey: objectIDs],
                    into: [context]
                )
                maybeCreateDefaults(context: context, request: self.fetchRequest)
            }
        } catch {
            let error = error as NSError
            fatalError("Unresolved error \(error), \(error.userInfo)")
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        NSLog("LatestObjectBinder controllerDidChangeContent")
        _ = maybeUpdateManagedObject()
    }
    
    private func maybeUpdateManagedObject() -> Bool {
        if let objects = self.controller.fetchedObjects {
            if !objects.isEmpty {
                NSLog("Updating managed object")
                self.managedObject = objects[0]
                return true
            }
        }
        return false
    }
    
    private func maybeCreateDefaults(
        context: NSManagedObjectContext,
        request: NSFetchRequest<T>)
    {
        let entityName = "\(T.self)"
        NSLog("maybeCreateDefaults " + entityName)
        do {
            let objects = try context.fetch(request)
            let count: Int = objects.count
            let str = String(count)
            NSLog(entityName + " object count: " + str)
            if !objects.isEmpty {
                return
            }
            NSLog("creating default " + entityName)
            // create new object
            let object = NSEntityDescription.insertNewObject(
                forEntityName: entityName,
                into: context) as! T
            try context.save()
        } catch {
            let error = error as NSError
            fatalError("Unresolved error \(error), \(error.userInfo)")
        }
    }
}
