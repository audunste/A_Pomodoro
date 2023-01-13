//
//  HistoryViewModel.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 08/01/2023.
//

import Combine
import Foundation
import CoreData

class HistoryViewModel: ObservableObject {
    
    @Published var people: [Person] = []
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
            print("apom change in history view model")
            self.updatePeople()
        }
        .store(in: &cancelSet)
        self.updatePeople()
    }
    
    func updatePeople() {
        let request = PomodoroEntry.fetchRequest()
        request.predicate = NSPredicate(format:"timerType == 'pomodoro'")
        do {
            let count = try viewContext?.count(for: request)
            people = [
                Person(name: "", pomodoroCount: count ?? 0, isYou: true)
            ]
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
}

struct Person: Identifiable, Hashable {
    let id: String
    let name: String
    let pomodoroCount: Int
    let isYou: Bool
    
    init (name: String, pomodoroCount: Int, isYou: Bool = false) {
        self.id = name
        self.name = name
        self.pomodoroCount = pomodoroCount
        self.isYou = isYou
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
