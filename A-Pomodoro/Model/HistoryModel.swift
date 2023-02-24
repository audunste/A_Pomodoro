//
//  HistoryModel.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 08/01/2023.
//

import Combine
import Foundation
import CoreData
import CloudKit

#if os(iOS)
import UIKit
#endif

class HistoryModel: ObservableObject {
    
    @Published public private(set) var people: [Person] = []
    @Published var activeId: String?
    @Published var processingReciprocationForId: String? = nil
    
    var activePerson: Person? {
        guard let activeId = activeId else {
            return nil
        }
        for person in people {
            if person.id == activeId {
                return person
            }
        }
        return nil
    }
    
    var activeHistory: History? {
        return PersistenceController.active.getHistoryByObjectIdUrl(string: activeId)
    }
    
    static let recentlyAcceptShareId: String = "recentlyAcceptShareId"
    var recentlyAcceptedShare: (String, CKUserIdentity.LookupInfo, Date)? = nil
    
    var cancelSet: Set<AnyCancellable> = []

    private var _viewContext: NSManagedObjectContext?
    var viewContext: NSManagedObjectContext? {
        set {
            _viewContext = newValue
            updatePeople()
        }
        get {
            return _viewContext
        }
    }

    init(viewContext: NSManagedObjectContext? = nil) {
        /*
        NotificationCenter.default.post(name: .pomodoroStoreDidChange, object: self, userInfo: userInfo)
        */
        ALog("New HistoryModel")
        self.viewContext = viewContext
        NotificationCenter.default.publisher(for: .pomodoroStoreDidChange)
        .throttle(for: .seconds(10.0), scheduler: RunLoop.main, latest: true)
        .sink {
            notification in
            ALog("Change in history view model")
            self.updatePeople()
            self.maybeTriggerAcceptReciprocateLink()
        }
        .store(in: &cancelSet)
        NotificationCenter.default.addObserver(forName: .shareAccepted, object: nil, queue: .main) { n in
            guard let userInfo = n.userInfo else {
                ALog(level: .warning, "No userInfo with .shareAccepted event")
                return
            }
            guard let lookupInfo = userInfo["lookupInfo"] as? CKUserIdentity.LookupInfo,
                let name = userInfo["name"] as? String else
            {
                ALog(level: .warning, "No lookupInfo or name with .shareAccepted event")
                return
            }
            self.shareAccepted(name: name, lookupInfo: lookupInfo)
        }
        self.updatePeople()
    }
    
    func shareAccepted(name: String, lookupInfo: CKUserIdentity.LookupInfo) {
        self.recentlyAcceptedShare = (name, lookupInfo, Date())
        self.activeId = Self.recentlyAcceptShareId
        self.updatePeople()
    }
    
    func setPeople(_ people: [Person], _ removeRecentlyAcceptedShareInFavourOf: NSManagedObjectID? = nil) {
        if let objectId = removeRecentlyAcceptedShareInFavourOf {
            recentlyAcceptedShare = nil
            activeId = objectId.uriRepresentation().absoluteString
        }
        if let (name, _, _) = recentlyAcceptedShare {
            let tempPerson = Person(id: Self.recentlyAcceptShareId, name: name, pomodoroCount: 0)
            var modPeople = people
            modPeople.insert(tempPerson, at: min(modPeople.count, 1))
            self.people = modPeople
        } else {
            self.people = people
        }
    }
    
    func applyProcessingReciprocation() {
        guard let processingId = activeId else {
            return
        }
        processingReciprocationForId = processingId
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            if self.processingReciprocationForId == processingId {
                self.processingReciprocationForId = nil
            }
        }
    }
    
    func reciprocateNotNow() {
        // Make Reciprocate object on active History with own lookUpHash and no share url
        applyProcessingReciprocation()
        let controller = PersistenceController.active
        controller.persistentContainer.viewContext.perform {
            guard
                let activeHistory = self.activeHistory,
                let activeShare = controller.getShare(for: activeHistory),
                let ownLookupInfoHash = activeShare.currentUserParticipant?.userIdentity.lookupInfo?.sha256Hash
            else {
                ALog(level: .warning, "Could not get active history, its share or own lookup info hash")
                return
            }
            let reciprocation = Reciprocate(context: controller.persistentContainer.viewContext)
            reciprocation.history = activeHistory
            reciprocation.lookupInfoHash = ownLookupInfoHash
            controller.persistentContainer.viewContext.saveAndLogError()
        }
    }
    
    func reciprocateShare() {
        // Make sure own History has a persisted share,
        // add the active share's owner as participant,
        // then make Reciprocate object on active History with own History share url
        applyProcessingReciprocation()
        let controller = PersistenceController.active
        controller.persistentContainer.viewContext.performAndWait {
            guard
                let activeHistory = activeHistory,
                let activeShare = controller.getShare(for: activeHistory),
                let ownLookupInfoHash = activeShare.currentUserParticipant?.userIdentity.lookupInfo?.sha256Hash,
                let container = controller.persistentCloudKitContainer
            else {
                ALog(level: .warning, "Could not get active history owner lookup info hash")
                return
            }
            controller.prepareHistoryShare { share in
                guard let share = share,
                    let lookupInfo = activeShare.owner.userIdentity.lookupInfo
                else {
                    ALog(level: .error, "Could not prepare history share")
                    return
                }
                controller.fetchParticipants(for: [lookupInfo]) { result in
                    switch result {
                    case .success(let participants):
                        if participants.count == 1 {
                            let participant = participants[0]
                            participant.permission = .readWrite
                            ALog("Add participant \(participant) to history share")
                            share.addParticipant(participant)
                            container.persistUpdatedShare(share, in: controller.privatePersistentStore) { (share, error) in
                                if let error = error {
                                    ALog(level: .error, "Failed to persist updated share: \(error)")
                                } else {
                                    let reciprocation = Reciprocate(context: controller.persistentContainer.viewContext)
                                    reciprocation.history = activeHistory
                                    reciprocation.lookupInfoHash = ownLookupInfoHash
                                    reciprocation.url = share?.url
                                    controller.persistentContainer.viewContext.saveAndLogError()
                                    ALog("Reciprocated to \(String(describing: activeShare.owner.userIdentity.lookupInfo))")
                                }
                            }
                        }
                        break
                    case .failure(let error):
                        ALog(level: .error, "\(error)")
                    }
                }
            }
        }
    }
    
    func maybeTriggerAcceptReciprocateLink() {
        let controller = PersistenceController.active
        let context = controller.persistentContainer.viewContext
        context.performAndWait {
            let history = controller.getOwnHistory()
            guard let reciprocations = history?.reciprocations else {
                return
            }
            for case let reciprocate as Reciprocate in reciprocations {
                if let url = reciprocate.url {
                    #if os(iOS)
                    ALog("Found reciprocate link")
                    DispatchQueue.main.async {
                        UIApplication.shared.open(url)
                    }
                    reciprocate.url = nil
                    context.saveAndLogError()
                    #endif
                    break
                }
            }
        }
    }
        
    var updatePeopleCts: CancellationTokenSource? = nil
    
    func newUpdatePeopleCt() -> CancellationToken {
        if let cts = updatePeopleCts {
            cts.cancel()
        }
        updatePeopleCts = CancellationTokenSource()
        return updatePeopleCts!.token
    }
    
    func updatePeople() {
        guard let viewContext = self.viewContext else {
            return
        }
        if people.isEmpty {
            viewContext.performAndWait {
                self.doUpdateOwnHistory()
            }
        }
        
        viewContext.perform {
            self.doUpdatePeople()
        }
    }
    
    func doUpdateOwnHistory() {
        let request = PomodoroEntry.fetchRequest()
        request.predicate = NSPredicate(format:"(timerType == 'pomodoro') AND (startDate != nil)")
        var pomodoroCount: Int = 0
        var historyId: NSManagedObjectID? = nil
        do {
            let entries = try request.execute()
            for entry in entries {
                if entry.isMine {
                    pomodoroCount += 1
                    if historyId == nil {
                        historyId = entry.task?.category?.history?.objectID
                    }
                }
            }
            if historyId == nil {
                let histories = try History.fetchRequest().execute()
                for history in histories {
                    if history.isMine {
                        historyId = history.objectID
                        break
                    }
                }
            }
        } catch {
            ALog("Error: \(error)")
        }
        if let historyId = historyId {
            setPeople([ Person(historyId: historyId, name: "", pomodoroCount: pomodoroCount, isYou: true)])
        }
    }

    func doUpdatePeople() {
        let token = newUpdatePeopleCt()
        let request = PomodoroEntry.fetchRequest()
        request.predicate = NSPredicate(format:"(timerType == 'pomodoro') AND (startDate != nil)")
        request.sortDescriptors = [NSSortDescriptor(key: "startDate", ascending: false)]
        do {
            var entriesByHistory = [History: [PomodoroEntry]]()
            let entries = try request.execute()
            for entry in entries {
                guard let history = entry.task?.category?.history else {
                    ALog(level: .warning, "Pomodoro with no History")
                    continue
                }
                var list = entriesByHistory[history] ?? []
                list.append(entry)
                entriesByHistory[history] = list
            }
            ALog("Entry count: \(entries.count)")
            let histories = try History.fetchRequest().execute()
            for history in histories {
                if entriesByHistory[history] == nil {
                    entriesByHistory[history] = []
                }
            }
            
            fetchNames(Array(entriesByHistory.keys), token: token) {
                result in
                if token.isCancellationRequested {
                    ALog("Cancelled")
                    return
                }
                switch result {
                case .success(let nameByHistory):
                    self.updatePeople(entriesByHistory, nameByHistory)
                case .failure(let error):
                    ALog(level: .error, "Failed updating people: \(error)")
                }
            }
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
    
    func updatePeople(_ entriesByHistory: [History: [PomodoroEntry]], _ nameByHistory: [History: String]) {
        var people = [Person]()
        
        var histories = Array(entriesByHistory.keys)
        let controller = PersistenceController.active
        var shareByHistory = [History: CKShare]()
        
        ALog("History count: \(histories.count)")
        for history in histories {
            shareByHistory[history] = controller.getShare(for: history)
        }
        
        let isYou:((History) -> Bool) = {
            history in
            let share = shareByHistory[history]
            return share == nil || share?.owner == share?.currentUserParticipant
        }
        
        histories.sort {
            let isYou0 = isYou($0)
            let isYou1 = isYou($1)
            if isYou0 {
                if !isYou1 {
                    return true
                }
                // both are you... weird
                ALog(level: .warning, "Two History objects seemingly belonging to you")
            } else if isYou1 {
                return false
            }
            let e0 = entriesByHistory[$0]
            let e1 = entriesByHistory[$1]
            if e0 == nil {
                return false
            } else if e1 == nil {
                return true
            } else if e0!.isEmpty {
                return false
            } else if e1!.isEmpty {
                return true
            } else {
                return (e0?[0].startDate ?? Date(timeIntervalSinceReferenceDate: 0))
                    < (e1?[0].startDate ?? Date(timeIntervalSinceReferenceDate: 0))
            }
        }
        
        var removeRecentlyAcceptedShareInFavourOf: NSManagedObjectID? = nil
        var ownHistory: History? = nil
        var sharedToLookupInfos = [CKUserIdentity.LookupInfo]()
        
        for history in histories {
            if isYou(history) {
                ownHistory = history
                if let share = controller.getShare(for: history) {
                    for participant in share.participants {
                        if let lookupInfo = participant.userIdentity.lookupInfo {
                            sharedToLookupInfos.append(lookupInfo)
                        }
                    }
                }
                break
            }
        }
        
        for history in histories {
            let entries = entriesByHistory[history]
            let isYou = history == ownHistory
            let name = isYou ? "" : nameByHistory[history]
            if let recentLookupInfo = recentlyAcceptedShare?.1,
                let share = shareByHistory[history]
            {
                ALog("\(String(describing: share.owner.userIdentity.lookupInfo)) \(String(describing: recentLookupInfo))")
                if share.owner.userIdentity.lookupInfo == recentLookupInfo {
                    removeRecentlyAcceptedShareInFavourOf = history.objectID
                }
            }
            var isReciprocating: Bool? = nil
            if !isYou,
                let reciprocations = history.reciprocations,
                let share = shareByHistory[history],
                let lookupInfoHash = share.currentUserParticipant?.userIdentity.lookupInfo?.sha256Hash
            {
                if let ownerLookupInfo = share.owner.userIdentity.lookupInfo,
                    sharedToLookupInfos.contains(ownerLookupInfo) {
                    ALog("Already shared to potential reciprocate user")
                    isReciprocating = true
                } else {
                    for case let reciprocation as Reciprocate in reciprocations {
                        if reciprocation.lookupInfoHash == lookupInfoHash {
                            isReciprocating = reciprocation.url != nil
                            break
                        }
                    }
                }
            }
            people.append(Person(historyId: history.objectID, name: name ?? "", pomodoroCount: entries?.count ?? 0, isYou: isYou, isReciprocating: isReciprocating))
        }
        
        ALog("Updating \(people.count) people")
        DispatchQueue.main.async {
            self.setPeople(people, removeRecentlyAcceptedShareInFavourOf)
        }
    }

    func fetchNames(_ histories: [History], token: CancellationToken, completion: @escaping (Result<[History: String], Error>) -> Void) {
        ALog("histories.count: \(histories.count)")
        do {
            guard let container = PersistenceController.shared.persistentCloudKitContainer else {
                completion(.success([History : String]()))
                return
            }
            let historyIDs = histories.map { $0.objectID }
            let sharesByID = try container.fetchShares(matching: historyIDs)
            
            var urls = [URL]()
            for history in histories {
                if let url = sharesByID[history.objectID]?.url {
                    urls.append(url)
                }
            }
            
            if urls.isEmpty {
                completion(.success([History : String]()))
                return
            }

            PersistenceController.shared.fetchShareMetadata(for: urls) {
                result in
                if token.isCancellationRequested {
                    ALog("Cancelled")
                    return
                }
                switch result {
                case .success(let cache):
                    var result = [History: String]()
                    for history in histories {
                        guard let url = sharesByID[history.objectID]?.url else {
                            continue
                        }
                        guard let metadata = cache[url] else {
                            ALog(level: .warning, "No metadata for share url \(url)")
                            continue
                        }
                        if let name = Self.nameFrom(metadata: metadata) {
                            result[history] = name
                        }
                    }
                    completion(.success(result))
                case .failure(let error):
                    ALog("Failure \(error)")
                    completion(.failure(error))
                }
            }
        } catch {
            if !token.isCancellationRequested {
                completion(.failure(error))
            } else {
                ALog("Cancelled")
            }
        }
    }
    
    static func nameFrom(metadata: CKShare.Metadata) -> String? {
        if let nameComponents = metadata.ownerIdentity.nameComponents {
            let name = PersonNameComponentsFormatter.localizedString(from: nameComponents, style: .short)
            if name.count > 0 {
                return name
            }
        }
        if let emailAddress = metadata.ownerIdentity.lookupInfo?.emailAddress {
            var name = emailAddress
            if let i = emailAddress.firstIndex(of: "@") {
                name = String(emailAddress.prefix(upTo: i))
            }
            if name.count > 0 {
                return name
            }
        }
        return nil
    }
}

struct Person: Identifiable, Hashable {
    let id: String
    let name: String
    let pomodoroCount: Int
    let isReciprocating: Bool?
    let isYou: Bool

    init (historyId: NSManagedObjectID, name: String, pomodoroCount: Int, isYou: Bool = false, isReciprocating: Bool? = nil) {
        self.init(id: historyId.uriRepresentation().absoluteString, name: name, pomodoroCount: pomodoroCount, isYou: isYou, isReciprocating: isReciprocating)
    }
    
    init (id: String, name: String, pomodoroCount: Int, isYou: Bool = false, isReciprocating: Bool? = nil) {
        self.id = id
        self.name = name
        self.pomodoroCount = pomodoroCount
        self.isYou = isYou
        self.isReciprocating = isReciprocating
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
