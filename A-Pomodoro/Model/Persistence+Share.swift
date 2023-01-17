//
//  Persistence+Share.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 12/01/2023.
//

import CoreData
import CloudKit
import UIKit

extension CKContainer {
    func getCurrentUserName() {
        CKContainer.default().requestApplicationPermission(.userDiscoverability) { (status, error) in
            CKContainer.default().fetchUserRecordID { (record, error) in
                CKContainer.default().discoverUserIdentity(withUserRecordID: record!, completionHandler: { (userID, error) in
                    print(userID?.hasiCloudAccount)
                    print(userID?.lookupInfo?.phoneNumber)
                    print(userID?.lookupInfo?.emailAddress)
                    print((userID?.nameComponents?.givenName)! + " " + (userID?.nameComponents?.familyName)!)
                })
            }
        }
    }
}

extension PersistenceController {
    
    func presentCloudSharingController() {
        guard let share = self.pomodoroHistoryShare else {
            ALog(level: .warning, "failed to retrieve pomodoroHistoryShare.")
            return
        }
        let sharingController = UICloudSharingController(share: share, container: cloudKitContainer)
        sharingController.availablePermissions = [.allowPrivate, .allowReadWrite]
        sharingController.delegate = self
        /**
         Setting the presentation style to .formSheet so there's no need to specify sourceView, sourceItem, or sourceRect.
         */
        if let viewController = rootViewController {
            sharingController.modalPresentationStyle = .formSheet
            viewController.present(sharingController, animated: true)
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
            self.pomodoroHistoryShare = nil
            purgeObjectsAndRecords(with: share)
        }
    }

    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        if let share = csc.share, let persistentStore = share.persistentStore {
            persistentCloudKitContainer.persistUpdatedShare(share, in: persistentStore) { (share, error) in
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


extension PersistenceController {
    
    func getShare(for object: NSManagedObject) -> CKShare? {
        var objectIDs = [object.objectID]
        let result = try? persistentCloudKitContainer.fetchShares(matching: objectIDs)
        return result?.values.first
    }
        
    func shareObject(_ unsharedObject: NSManagedObject, to existingShare: CKShare?,
                     completionHandler: ((_ share: CKShare?, _ error: Error?) -> Void)? = nil)
    {
        shareObjects([unsharedObject], to: existingShare, completionHandler: completionHandler)
    }
    
    func shareObjects(_ unsharedObjects: [NSManagedObject], to existingShare: CKShare?,
                     completionHandler: ((_ share: CKShare?, _ error: Error?) -> Void)? = nil)
    {
        persistentCloudKitContainer.share(unsharedObjects, to: existingShare) { (objectIDs, share, container, error) in
            guard error == nil, let share = share else {
                ALog(level: .error, "Failed to share an object: \(error!))")
                completionHandler?(share, error)
                return
            }
            /**
             Synchronize the changes on the share to the private persistent store.
             */
            self.persistentCloudKitContainer.persistUpdatedShare(share, in: self.privatePersistentStore) { (share, error) in
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
        guard let store = (persistentStore ?? share.persistentStore) else {
            ALog(level: .error, "Failed to find the persistent store for share. \(share))")
            return
        }
        persistentCloudKitContainer.purgeObjectsAndRecordsInZone(with: share.recordID.zoneID, in: store) { (zoneID, error) in
            if let error = error {
                ALog(level: .error, "Failed to purge objects and records: \(error)")
            }
        }
    }

    func share(with title: String) -> CKShare? {
        let stores = [privatePersistentStore, sharedPersistentStore]
        let shares = try? persistentCloudKitContainer.fetchShares(in: stores)
        let share = shares?.first(where: { $0.title == title })
        return share
    }
    
    func shareTitles() -> [String] {
        let stores = [privatePersistentStore, sharedPersistentStore]
        let shares = try? persistentCloudKitContainer.fetchShares(in: stores)
        return shares?.map { $0.title } ?? []
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
        if let shares = try? persistentContainer.fetchShares(in: privatePersistentStore) {
            let zoneIDs = shares.map { $0.recordID.zoneID }
            if zoneIDs.contains(recordID.zoneID) {
                return privatePersistentStore
            }
        }
        let sharedPersistentStore = PersistenceController.shared.sharedPersistentStore
        if let shares = try? persistentContainer.fetchShares(in: sharedPersistentStore) {
            let zoneIDs = shares.map { $0.recordID.zoneID }
            if zoneIDs.contains(recordID.zoneID) {
                return sharedPersistentStore
            }
        }
        return nil
    }
}

