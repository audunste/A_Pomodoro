//
//  HistoryViewModel.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 08/01/2023.
//

import Combine
import Foundation
import CoreData
import CloudKit

class HistoryViewModel: ObservableObject {
    
    @Published var people: [Person] = []
    @Published var activeId: NSManagedObjectID?
    
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
        self.viewContext = viewContext
        NotificationCenter.default.publisher(for: .pomodoroStoreDidChange)
        .throttle(for: .seconds(10.0), scheduler: RunLoop.main, latest: true)
        .sink {
            notification in
            ALog("change in history view model")
            self.updatePeople()
        }
        .store(in: &cancelSet)
        self.updatePeople()
    }
    
    func updatePeople() {
        self.viewContext?.perform {
            self.doUpdatePeople()
        }
    }
    
    func doUpdatePeople() {
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
            
            fetchNames(Array(entriesByHistory.keys)) {
                result in
                switch result {
                case .success(let nameByHistory):
                    self.updatePeople(entriesByHistory, nameByHistory)
                case .failure(let error):
                    ALog(level: .error, "Failed updating people: \(error)")
                }
            }

            /*
            let count = try viewContext?.count(for: request)
            people = [
                Person(name: "", pomodoroCount: count ?? 0, isYou: true)
            ]
            */
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
    
    func updatePeople(_ entriesByHistory: [History: [PomodoroEntry]], _ nameByHistory: [History: String]) {
        var people = [Person]()
        
        var histories = Array(entriesByHistory.keys)
        let controller = PersistenceController.shared
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
        
        for history in histories {
            let entries = entriesByHistory[history]
            let isYou = isYou(history)
            let name = isYou ? "" : nameByHistory[history]
            people.append(Person(historyId: history.objectID, name: name ?? "", pomodoroCount: entries?.count ?? 0, isYou: isYou))
        }
        ALog("Updating \(people.count) people")
        DispatchQueue.main.async {
            self.people = people
        }
    }
    
    func fetchNames(_ histories: [History], completion: @escaping (Result<[History: String], Error>) -> Void) {
        do {
            let container = PersistenceController.shared.persistentCloudKitContainer
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
                        if let nameComponents = metadata.ownerIdentity.nameComponents {
                            let name = PersonNameComponentsFormatter.localizedString(from: nameComponents, style: .short)
                            if name.count > 0 {
                                result[history] = name
                                continue
                            }
                        }
                        if let emailAddress = metadata.ownerIdentity.lookupInfo?.emailAddress {
                            var name = emailAddress
                            if let i = emailAddress.firstIndex(of: "@") {
                                name = String(emailAddress.prefix(upTo: i))
                            }
                            if name.count > 0 {
                                result[history] = name
                            }
                        }
                    }
                    completion(.success(result))
                case .failure(let error):
                    ALog("Failure \(error)")
                    completion(.failure(error))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
}

struct Person: Identifiable, Hashable {
    let id: NSManagedObjectID
    let name: String
    let pomodoroCount: Int
    let isYou: Bool
    
    init (historyId: NSManagedObjectID, name: String, pomodoroCount: Int, isYou: Bool = false) {
        self.id = historyId
        self.name = name
        self.pomodoroCount = pomodoroCount
        self.isYou = isYou
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
