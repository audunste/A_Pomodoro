//
//  HistoryViewModel.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 08/01/2023.
//

import Foundation
import CoreData

class HistoryViewModel: ObservableObject {
    
    @Published var people: [Person] = []
    let viewContext: NSManagedObjectContext
    
    init(viewContext: NSManagedObjectContext) {
        /*
        NotificationCenter.default.post(name: .pomodoroStoreDidChange, object: self, userInfo: userInfo)
        */
        self.viewContext = viewContext
        NotificationCenter.default.addObserver(forName: .pomodoroStoreDidChange, object: nil, queue: .main)
        {
            notification in
            print("apom change in history view model")
            self.updatePeople()
        }
        self.updatePeople()
    }
    
    func updatePeople() {
        let request = PomodoroEntry.fetchRequest()
        request.predicate = NSPredicate(format:"timerType == 'pomodoro'")
        do {
            let count = try viewContext.count(for: request)
            people = [
                Person(name: "", pomodoroCount: count, isYou: true)
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
