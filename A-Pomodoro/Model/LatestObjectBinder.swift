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
    private let postFilter: ((T) -> Bool)?
    
    @Published var managedObject: T? = nil

    init(container: NSPersistentContainer, sortKey: String, predicate: NSPredicate? = nil, postFilter: ((T) -> Bool)? = nil) {
        let context = container.viewContext
        let entityName = "\(T.self)"
        self.fetchRequest = NSFetchRequest<T>(entityName: entityName)
        self.fetchRequest.sortDescriptors = [NSSortDescriptor(key: sortKey, ascending: false)]
        if predicate != nil {
            self.fetchRequest.predicate = predicate
        }
        self.postFilter = postFilter
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
    
    var managedObjectDebugString: String {
        guard let object = managedObject as? NSManagedObject else {
            return "nil"
        }
        return object.debugString(with: controller.managedObjectContext)
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
        ALog("deleteAllAndSave")
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
        ALog("LatestObjectBinder controllerDidChangeContent")
        _ = maybeUpdateManagedObject()
    }
    
    private func maybeUpdateManagedObject() -> Bool {
        if let objects = self.controller.fetchedObjects {
            if !objects.isEmpty {
                if let postFilter = self.postFilter {
                    self.managedObject = objects.filter { postFilter($0) }.first
                } else {
                    self.managedObject = objects.first
                }
                ALog("updating managed object \(self.managedObjectDebugString)")
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
        ALog("maybeCreateDefaults " + entityName)
        do {
            let objects = try context.fetch(request)
            let count: Int = objects.count
            let str = String(count)
            ALog(entityName + " object count: " + str)
            if !objects.isEmpty {
                return
            }
            ALog("creating default " + entityName)
            // create new object
            _ = NSEntityDescription.insertNewObject(
                forEntityName: entityName,
                into: context) as! T
            try context.save()
        } catch {
            let error = error as NSError
            fatalError("Unresolved error \(error), \(error.userInfo)")
        }
    }
}
