//
//  A_PomodoroApp.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 21/12/2022.
//

import SwiftUI

@main
struct A_PomodoroApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var modelData = ModelData()

    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        { success, error in
            if let error = error {
                print(error.localizedDescription)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(modelData)
                .preferredColorScheme(.dark)
        }
    }
}
