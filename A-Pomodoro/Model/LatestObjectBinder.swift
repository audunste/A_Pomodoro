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

    init(container: NSPersistentContainer,
        sortKey: String,
        predicate: NSPredicate? = nil,
        delayedInit: Bool = false,
        postFilter: ((T) -> Bool)? = nil)
    {
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
        if delayedInit {
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { t in
                self.postinitWrapper(container)
            }
        } else {
            postinitWrapper(container)
        }
    }
    
    
    
    var managedObjectDebugString: String {
        guard let object = managedObject as? NSManagedObject else {
            return "nil"
        }
        return object.debugString(with: controller.managedObjectContext)
    }
    
    private func postinitWrapper(_ container: NSPersistentContainer) {
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
        _ = maybeUpdateManagedObject()
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
    
}
