//
//  A_PomodoroApp.swift
//  A-Pomodoro
//
//  Created by Audun Steinholm on 21/12/2022.
//

import SwiftUI

@main
struct A_PomodoroApp: App {
    @UIApplicationDelegateAdaptor var appDelegate: AppDelegate
    let persistentContainer = PersistenceController.shared.persistentContainer
    @StateObject private var modelData = ModelData()
    @StateObject private var lastPomodoroEntryBinder = LatestObjectBinder<PomodoroEntry>(
        container: PersistenceController.shared.persistentContainer,
        sortKey: "startDate")

    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        { success, error in
            if let error = error {
                print(error.localizedDescription)
            }
        }
    }

    var body: some Scene {
        #if InitializeCloudKitSchema
        WindowGroup {
            Text("Initializing CloudKit Schema...").font(.title)
            Text("Stop after Xcode says 'no more requests to execute', " +
                 "then check with CloudKit Console if the schema is created correctly.").padding()
        }
        #else
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistentContainer.viewContext)
                .environmentObject(modelData)
                .environmentObject(lastPomodoroEntryBinder)
                .preferredColorScheme(.dark)
        }
        #endif
    }
}
