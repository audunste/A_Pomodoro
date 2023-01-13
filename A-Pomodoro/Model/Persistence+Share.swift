//
//  Persistence+Share.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 12/01/2023.
//

import CoreData
import CloudKit

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
                print("\(#function): Failed to share an object: \(error!))")
                completionHandler?(share, error)
                return
            }
            /**
             Synchronize the changes on the share to the private persistent store.
             */
            self.persistentCloudKitContainer.persistUpdatedShare(share, in: self.privatePersistentStore) { (share, error) in
                if let error = error {
                    print("\(#function): Failed to persist updated share: \(error)")
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
            print("\(#function): Failed to find the persistent store for share. \(share))")
            return
        }
        persistentCloudKitContainer.purgeObjectsAndRecordsInZone(with: share.recordID.zoneID, in: store) { (zoneID, error) in
            if let error = error {
                print("\(#function): Failed to purge objects and records: \(error)")
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

