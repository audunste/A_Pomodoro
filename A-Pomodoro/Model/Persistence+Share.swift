//
//  Persistence+Share.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 12/01/2023.
//

import Foundation
import CoreData
import CloudKit
import CryptoKit


extension Notification.Name {
    static let shareAccepted = Notification.Name("shareAccepted")
    static let cloudSharingViewDidAppear = Notification.Name("cloudSharingViewDidAppear")
}

#if os(iOS)

import UIKit
import ObjectiveC.runtime

extension UICloudSharingController {

    typealias ViewWillAppearRef = @convention(c)(UICloudSharingController, Selector, Bool) -> Void
    private static let viewDidAppearSelector = #selector(UICloudSharingController.viewDidAppear(_:))
    
    static func swizzle() {
        guard let originalMethod = class_getInstanceMethod(Self.self, viewDidAppearSelector) else {
            ALog(level: .warning, "Could not find viewDidAppear selector to swizzle")
            return
        }

        var originalIMP: IMP? = nil
        
        let swizzledBlock: @convention(block) (UICloudSharingController, Bool) -> Void = { receiver, animated in
            if let originalIMP = originalIMP {
                let castedIMP = unsafeBitCast(originalIMP, to: ViewWillAppearRef.self)
                castedIMP(receiver, viewDidAppearSelector, animated)
            }
            guard type(of: receiver) == UICloudSharingController.self else {
                return
            }
            NotificationCenter.default.post(name: .cloudSharingViewDidAppear, object: nil)
        }
        
        let swizzledIMP = imp_implementationWithBlock(unsafeBitCast(swizzledBlock, to: AnyObject.self))
        originalIMP = method_setImplementation(originalMethod, swizzledIMP)
    }
}


extension PersistenceController {

    func presentCloudSharingController() {
        persistentContainer.viewContext.performAndWait {
            if let history = getOwnHistory() {
                presentCloudSharingController(history: history)
            }
        }
    }
    func presentCloudSharingController(history: History) {
        /**
         Grab the share if the history is already shared.
         */
        guard let container = persistentCloudKitContainer else {
            return
        }
        var historyShare: CKShare?
        if let shareSet = try? container.fetchShares(matching: [history.objectID]),
           let (_, share) = shareSet.first {
            historyShare = share
        }

        let sharingController: UICloudSharingController
        if historyShare == nil {
            sharingController = newSharingController(unsharedHistory: history, persistenceController: self)
        } else {
            sharingController = UICloudSharingController(share: historyShare!, container: cloudKitContainer)
        }
        sharingController.delegate = self
        sharingController.availablePermissions = [.allowPrivate, .allowReadWrite]
        
        /**
         Setting the presentation style to .formSheet so there's no need to specify sourceView, sourceItem, or sourceRect.
         */
        if let viewController = rootViewController {
            sharingController.modalPresentationStyle = .formSheet
            ALog("before present")
            viewController.present(sharingController, animated: true)
        }
    }
    
    private func newSharingController(unsharedHistory: History, persistenceController: PersistenceController) -> UICloudSharingController {
        return UICloudSharingController { (_, completion: @escaping (CKShare?, CKContainer?, Error?) -> Void) in
            /**
             If the share's publicPermission is CKShareParticipantPermissionNone, only private participants can accept the share.
             Private participants mean the participants an app adds to a share by calling CKShare.addParticipant.
             If the share is more permissive, and is, therefore, a public share, anyone with the shareURL can accept it,
             or self-add themselves to it.
             The default value of publicPermission is CKShare.ParticipantPermission.none.
             */
            guard let container = self.persistentCloudKitContainer else {
                return
            }
            container.share([unsharedHistory], to: nil) { objectIDs, share, container, error in
                if let share = share {
                    self.configure(share: share)
                }
                completion(share, container, error)
            }
        }
    }

    private var rootViewController: UIViewController? {
        for scene in UIApplication.shared.connectedScenes {
            if scene.activationState == .foregroundActive,
               let sceneDeleate = (scene as? UIWindowScene)?.delegate as? UIWindowSceneDelegate,
               let window = sceneDeleate.window
            {
                return window?.rootViewController
            }
        }
        ALog(level: .error, "Failed to retrieve the window's root view controller.")
        return nil
    }
}

extension PersistenceController: UICloudSharingControllerDelegate {
    /**
     CloudKit triggers the delegate method in two cases:
     - An owner stops sharing a share.
     - A participant removes themselves from a share by tapping the Remove Me button in UICloudSharingController.
     
     After stopping the sharing,  purge the zone or just wait for an import to update the local store.
     This sample chooses to purge the zone to avoid stale UI. That triggers a "zone not found" error because UICloudSharingController
     deletes the zone, but the error doesn't really matter in this context.
     
     Purging the zone has a caveat:
     - When sharing an object from the owner side, Core Data moves the object to the shared zone.
     - When calling purgeObjectsAndRecordsInZone, Core Data removes all the objects and records in the zone.
     To keep the objects, deep copy the object graph you want to keep and make sure no object in the new graph is associated with any share.
     
     The purge API posts an NSPersistentStoreRemoteChange notification after finishing its job, so observe the notification to update
     the UI, if necessary.
     */
    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        if let share = csc.share {
            unshareObjectsAndRecords(with: share)
        }
    }

    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        if let share = csc.share, let persistentStore = share.persistentStore, let container = persistentCloudKitContainer {
            container.persistUpdatedShare(share, in: persistentStore) { (share, error) in
                if let error = error {
                    ALog(level: .error, "Failed to persist updated share: \(error)")
                }
            }
        }
    }

    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        ALog(level: .error, "Failed to save a share: \(error)")
    }
    
    func itemTitle(for csc: UICloudSharingController) -> String? {
        return csc.share?.title ?? NSLocalizedString("Pomodoro history", comment: "Default name of share")
    }
}

#endif


extension PersistenceController {
    
    func getShare(for object: NSManagedObject) -> CKShare? {
        let objectIDs = [object.objectID]
        let result = try? persistentCloudKitContainer?.fetchShares(matching: objectIDs)
        return result?.values.first
    }
    
    func prepareHistoryShare(completion: @escaping (CKShare?) -> Void) {
        guard let history = getOwnHistory() else {
            completion(nil)
            return
        }
        prepareShare(for: history) {
            share in
            completion(share)
        }
    }
    
    func prepareShare(for history: History, completion: @escaping (CKShare?) -> Void) {
        if let share = getShare(for: history) {
            configure(share: share, with: history)
            completion(share)
            return
        }
        shareObject(history, to: nil) {
            share, error in
            if let share = share {
                self.configure(share: share, with: history)
                completion(share)
                return
            }
            if let error = error {
                ALog(level: .error, "Failed to share History: \(error)")
                completion(nil)
            }
        }
    }
        
    func shareObject(_ unsharedObject: NSManagedObject, to existingShare: CKShare?,
                     completionHandler: ((_ share: CKShare?, _ error: Error?) -> Void)? = nil)
    {
        shareObjects([unsharedObject], to: existingShare, completionHandler: completionHandler)
    }
    
    func shareObjects(_ unsharedObjects: [NSManagedObject], to existingShare: CKShare?,
                     completionHandler: ((_ share: CKShare?, _ error: Error?) -> Void)? = nil)
    {
        guard let cloudKitContainer = persistentCloudKitContainer else {
            return
        }
        cloudKitContainer.share(unsharedObjects, to: existingShare) { (objectIDs, share, container, error) in
            guard error == nil, let share = share else {
                ALog(level: .error, "Failed to share an object: \(error!))")
                completionHandler?(share, error)
                return
            }
            /**
             Synchronize the changes on the share to the private persistent store.
             */
            cloudKitContainer.persistUpdatedShare(share, in: self.privatePersistentStore) { (share, error) in
                if let error = error {
                    ALog(level: .error, "Failed to persist updated share: \(error)")
                }
                completionHandler?(share, error)
            }
        }
    }
    
    /**
     Delete the Core Data objects and the records in the CloudKit record zone associated with the share.
     */
    func purgeObjectsAndRecords(with share: CKShare, in persistentStore: NSPersistentStore? = nil) {
        guard let store = (persistentStore ?? share.persistentStore), let container = persistentCloudKitContainer else {
            ALog(level: .error, "Failed to find the persistent store for share. \(share))")
            return
        }
        container.purgeObjectsAndRecordsInZone(with: share.recordID.zoneID, in: store) { (zoneID, error) in
            if let error = error {
                ALog(level: .error, "Failed to purge objects and records: \(error)")
            }
        }
    }
    
    func unshareObjectsAndRecords(with share: CKShare) {
        performAndWait { context in
            guard let history = getOwnHistory(), let historyShare = getShare(for: history) else {
                ALog(level: .error, "No shared own history when unsharing")
                return
            }
            if share.recordID != historyShare.recordID {
                ALog(level: .error, "Trying to unshare something that isn't the own history share. Not supported")
                return
            }
            ALog("")
            let _ = history.clone(into: context)
            context.delete(history)
            context.saveAndLogError()
        }
    }

    func share(with title: String) -> CKShare? {
        let stores = [privatePersistentStore, sharedPersistentStore]
        let shares = try? persistentCloudKitContainer?.fetchShares(in: stores)
        let share = shares?.first(where: { $0.title == title })
        return share
    }
    
    func shareTitles() -> [String] {
        let stores = [privatePersistentStore, sharedPersistentStore]
        let shares = try? persistentCloudKitContainer?.fetchShares(in: stores)
        return shares?.map { $0.title } ?? []
    }
    
    func configure(share: CKShare, with history: History? = nil) {
        share[CKShare.SystemFieldKey.title] = NSLocalizedString("Pomodoro history", comment: "Default name of share")
        // TODO thumbnail
    }
    
}

extension CKShare.ParticipantAcceptanceStatus {
    var stringValue: String {
        return ["Unknown", "Pending", "Accepted", "Removed"][rawValue]
    }
}

extension CKShare {
    var title: String {
        guard let date = creationDate else {
            return "Share-\(UUID().uuidString)"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return "Share-" + formatter.string(from: date)
    }
    
    var persistentStore: NSPersistentStore? {
        let persistentContainer = PersistenceController.shared.persistentCloudKitContainer
        let privatePersistentStore = PersistenceController.shared.privatePersistentStore
        if let shares = try? persistentContainer?.fetchShares(in: privatePersistentStore) {
            let zoneIDs = shares.map { $0.recordID.zoneID }
            if zoneIDs.contains(recordID.zoneID) {
                return privatePersistentStore
            }
        }
        let sharedPersistentStore = PersistenceController.shared.sharedPersistentStore
        if let shares = try? persistentContainer?.fetchShares(in: sharedPersistentStore) {
            let zoneIDs = shares.map { $0.recordID.zoneID }
            if zoneIDs.contains(recordID.zoneID) {
                return sharedPersistentStore
            }
        }
        return nil
    }
    
    var ownerLookupInfoHash: String? {
        guard let lookupInfo = self.owner.userIdentity.lookupInfo else {
            return nil
        }
        return lookupInfo.sha256Hash
    }
}

extension CKUserIdentity.LookupInfo {
    var sha256Hash: String? {
        guard let digest = self.emailAddress ?? self.phoneNumber else {
            return nil
        }
        let digestData = Data(digest.utf8)
        let hashed = SHA256.hash(data: digestData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

